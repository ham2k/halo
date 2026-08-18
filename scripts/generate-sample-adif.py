#!/usr/bin/env python3
"""Build a large sample ADIF log from a real one.

Takes a source ADIF export, rewrites the station callsign, keeps every real QSO
(calls, names, QTH, grid, DXCC...) and then synthesizes extra QSOs by pairing
the real contacts with new random dates/times/bands/modes drawn from the
distributions found in the source file, until the requested total is reached.

Usage:
  ./generate-sample-adif.py SOURCE.adi --station-call K2HRC/T --total 100000 -o out.adi
"""

import argparse
import random
import re
import sys
from datetime import datetime, timedelta

FIELD_RE = re.compile(r"<([A-Za-z0-9_]+)(?::(\d+)(?::[A-Za-z])?)?>", re.ASCII)

# Fields describing the station doing the logging: carried over unchanged.
MY_FIELD_PREFIX = "my_"
STATION_FIELDS = ("station_callsign", "operator", "owner_callsign")

# Fields describing the other station: reused verbatim for generated QSOs.
CONTACT_FIELDS = (
    "call", "name", "qth", "gridsquare", "country", "dxcc", "cont",
    "cqz", "ituz", "state", "cnty", "lat", "lon", "email", "iota",
    "continent", "address", "age", "qsl_via",
)

# Per-QSO fields we regenerate rather than copy.
QSO_FIELDS = (
    "qso_date", "time_on", "qso_date_off", "time_off", "band", "band_rx",
    "mode", "submode", "freq", "freq_rx", "rst_sent", "rst_rcvd", "tx_pwr",
    "comment", "distance",
)


def parse_adif(path):
    """Yield (record dict, header text) from an ADIF file."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        data = fh.read()

    lower = data.lower()
    eoh = lower.find("<eoh>")
    header = data[:eoh] if eoh >= 0 else ""
    body = data[eoh + 5:] if eoh >= 0 else data

    records = []
    record = {}
    pos = 0
    while True:
        m = FIELD_RE.search(body, pos)
        if not m:
            break
        name = m.group(1).lower()
        if name in ("eor", "eoh"):
            if record:
                records.append(record)
            record = {}
            pos = m.end()
            continue
        if m.group(2) is None:  # a tag with no length, e.g. <eoh>
            pos = m.end()
            continue
        length = int(m.group(2))
        value = body[m.end():m.end() + length]
        record[name] = value
        pos = m.end() + length
    if record:
        records.append(record)
    return header, records


def field(name, value):
    value = "" if value is None else str(value)
    return f"<{name}:{len(value.encode('utf-8'))}>{value}"


def write_record(out, record, order):
    parts = [field(k, record[k]) for k in order if k in record]
    parts += [field(k, v) for k, v in record.items() if k not in order]
    out.write("".join(parts) + "<eor>\n")


def rst_for(mode, rng):
    if mode in ("FT8", "FT4", "JT9", "JT65", "MSK144", "FST4"):
        return f"{rng.randint(-24, 3):+03d}".replace("+", "+")
    if mode in ("CW", "RTTY", "PSK31", "PSK", "OLIVIA", "MFSK"):
        return f"5{rng.randint(5, 9)}{rng.randint(7, 9)}"
    return f"5{rng.randint(3, 9)}"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="source ADIF file")
    ap.add_argument("--station-call", required=True,
                    help="callsign to use as station_callsign/operator in the output")
    ap.add_argument("--source-call", default=None,
                    help="callsign to replace (default: most common station_callsign in the source)")
    ap.add_argument("--total", type=int, default=100000,
                    help="target number of QSOs (default 100000)")
    ap.add_argument("--jitter", type=int, default=2000,
                    help="add a random 0..JITTER extra QSOs so the total isn't round (default 2000)")
    ap.add_argument("-o", "--output", default=None,
                    help="output file (default: sample-<call>-<count>.adi)")
    ap.add_argument("--seed", type=int, default=None, help="random seed for reproducible output")
    ap.add_argument("--start-date", default=None, help="YYYYMMDD; defaults to earliest source QSO")
    ap.add_argument("--end-date", default=None, help="YYYYMMDD; defaults to latest source QSO")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    target = args.total + (rng.randint(1, args.jitter) if args.jitter > 0 else 0)

    print(f"Reading {args.source} ...", file=sys.stderr)
    header, records = parse_adif(args.source)
    if not records:
        sys.exit("No QSO records found in source file.")
    print(f"  {len(records)} source QSOs", file=sys.stderr)

    field_order = list(records[0].keys())

    # --- callsign being replaced
    source_call = args.source_call
    if not source_call:
        counts = {}
        for rec in records:
            call = rec.get("station_callsign")
            if call:
                counts[call] = counts.get(call, 0) + 1
        source_call = max(counts, key=counts.get) if counts else ""
    print(f"  replacing station call {source_call!r} with {args.station_call!r}", file=sys.stderr)
    call_re = re.compile(re.escape(source_call), re.IGNORECASE) if source_call else None

    # --- station-side field sets: each generated QSO reuses one real set, so
    #     location/POTA/SOTA references stay internally consistent.
    my_field_sets = []
    seen_sets = set()
    for rec in records:
        my = tuple(sorted((k, v) for k, v in rec.items() if k.startswith(MY_FIELD_PREFIX)))
        if my and my not in seen_sets:
            seen_sets.add(my)
            my_field_sets.append(dict(my))
    if not my_field_sets:
        my_field_sets = [{}]
    print(f"  {len(my_field_sets)} distinct station-side field sets", file=sys.stderr)

    # --- unique contacts
    contacts = {}
    for rec in records:
        call = rec.get("call", "").upper()
        if not call:
            continue
        contact = {k: rec[k] for k in CONTACT_FIELDS if rec.get(k)}
        contact["call"] = call
        # prefer the most complete version of a repeated contact
        if len(contact) > len(contacts.get(call, {})):
            contacts[call] = contact
    contact_list = list(contacts.values())
    print(f"  {len(contact_list)} unique contacts", file=sys.stderr)

    # --- band/mode/freq distributions, learned from the source
    combos = {}
    for rec in records:
        band, mode = rec.get("band"), rec.get("mode")
        if not band or not mode:
            continue
        entry = combos.setdefault((band.lower(), mode.upper()), [])
        freq = rec.get("freq")
        if freq:
            entry.append(freq)
    combo_keys = list(combos.keys())
    combo_weights = [max(len(combos[k]), 1) for k in combo_keys]

    def date_bounds():
        dates = sorted(r["qso_date"] for r in records if r.get("qso_date"))
        return dates[0], dates[-1]

    src_start, src_end = date_bounds()
    start = datetime.strptime(args.start_date or src_start, "%Y%m%d")
    end = datetime.strptime(args.end_date or src_end, "%Y%m%d")
    span = max(int((end - start).total_seconds()), 60)
    print(f"  date range {start:%Y-%m-%d} .. {end:%Y-%m-%d}", file=sys.stderr)

    # --- rewrite the real QSOs
    out_records = []
    for rec in records:
        rec = dict(rec)
        for f in STATION_FIELDS:
            if f in rec:
                rec[f] = args.station_call
        rec.setdefault("station_callsign", args.station_call)
        if call_re:
            for k, v in rec.items():
                if k != "call" and source_call.upper() in v.upper():
                    rec[k] = call_re.sub(args.station_call, v)
        out_records.append(rec)

    # --- generate the rest
    needed = max(target - len(out_records), 0)
    print(f"  generating {needed} additional QSOs (target {target})", file=sys.stderr)

    for _ in range(needed):
        contact = dict(rng.choice(contact_list))
        band, mode = rng.choices(combo_keys, weights=combo_weights, k=1)[0]
        freqs = combos[(band, mode)]
        freq = rng.choice(freqs) if freqs else ""

        # Cluster QSOs into operating sessions: bias toward evenings/weekends.
        when = start + timedelta(seconds=rng.randint(0, span))
        when = when.replace(hour=rng.choice([0, 1, 2, 3, 11, 12, 13, 14, 18, 19, 20, 21, 22, 23]),
                            minute=rng.randint(0, 59), second=0)
        duration = timedelta(minutes=rng.randint(1, 4) if mode in ("FT8", "FT4") else rng.randint(1, 12))
        off = when + duration

        rec = dict(rng.choice(my_field_sets))
        rec.update(contact)
        rec["station_callsign"] = args.station_call
        rec["operator"] = args.station_call
        rec["qso_date"] = when.strftime("%Y%m%d")
        rec["time_on"] = when.strftime("%H%M%S")
        rec["qso_date_off"] = off.strftime("%Y%m%d")
        rec["time_off"] = off.strftime("%H%M%S")
        rec["band"] = band
        rec["mode"] = mode
        if freq:
            rec["freq"] = freq
        rec["rst_sent"] = rst_for(mode, rng)
        rec["rst_rcvd"] = rst_for(mode, rng)
        rec["tx_pwr"] = rng.choice(["5", "10", "25", "50", "100", "100", "100", "500"])
        rec["qsl_sent"] = rng.choice(["N", "N", "N", "Y"])
        rec["qsl_rcvd"] = rng.choice(["N", "N", "N", "Y"])
        out_records.append(rec)

    out_records.sort(key=lambda r: (r.get("qso_date", ""), r.get("time_on", "")))

    out_path = args.output or f"sample-{args.station_call.replace('/', '-')}-{len(out_records)}.adi"
    now = datetime.now()
    with open(out_path, "w", encoding="utf-8") as out:
        out.write(f"Sample ADIF log for {args.station_call}\n")
        out.write(f"    Generated: {now:%a %b %d %H:%M:%S %Y}\n")
        out.write(f"    Source: {args.source}\n")
        out.write(f"    Records: {len(out_records)}\n")
        out.write(field("ADIF_VER", "3.1.1") + "\n")
        out.write(field("PROGRAMID", "generate-sample-adif") + "\n")
        out.write(field("CREATED_TIMESTAMP", now.strftime("%Y%m%d %H%M%S")) + "\n")
        out.write("<EOH>\n\n")
        for rec in out_records:
            write_record(out, rec, field_order)

    print(f"Wrote {len(out_records)} QSOs to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
