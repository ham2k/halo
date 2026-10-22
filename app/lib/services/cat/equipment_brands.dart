// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who makes the radios in the catalogue, as the catalogue and the Add
// Equipment dialog both have to spell them. One file so that a model and the
// shelf it lands on cannot disagree about a brand's spelling.

/// The brands the Add Equipment dialog gives a group of their own, in the
/// order it lists them, and the spellings every model of each must use — a
/// model whose [EquipmentModel.manufacturer] differs by so much as a letter
/// files itself under "Other Brands" instead. Not localized, for the same
/// reason [EquipmentModel.manufacturer] is not: a brand is spelled the same
/// in every language.
///
/// Alphabetical rather than ranked: any other order is an opinion about
/// whose radios matter, and this list is long-lived.
const featuredBrands = [elecraftBrand, flexBrand, icomBrand, kenwoodBrand, yaesuBrand];

const elecraftBrand = 'Elecraft';
const flexBrand = 'FlexRadio';
const icomBrand = 'Icom';
const kenwoodBrand = 'Kenwood';
const yaesuBrand = 'Yaesu';

/// Not featured, so its radios shelve under "Other Brands" — but spelled
/// once, because two entries carry it and a hardware report files by it.
const qrpLabsBrand = 'QRP Labs';

/// Not featured either; spelled once for the same reason.
const xieguBrand = 'Xiegu';

/// Not featured either; spelled once for the same reason.
const lab599Brand = 'Lab599';

/// Not featured either; spelled once for the same reason.
const tenTecBrand = 'Ten-Tec';

/// The models that are not a radio but a way to reach one: a program on the
/// same machine that owns the rig's port and answers for it. Keyed by
/// [EquipmentModel.key], because these name a protocol or a program rather
/// than a maker and so have no manufacturer to shelve them by.
///
/// Their own shelf because the question they answer is a different one. An
/// operator browsing brands is looking for what is on their desk; one
/// reaching for flrig already knows their radio is not directly reachable.
/// A bridge added later belongs here — nothing derives this list, and one
/// left out lands under "Other Brands" with the radios.
const softwareIntermediaryModelKeys = ['flrig', 'rigctld', 'hrd', 'n3fjp', 'dxlab-commander'];
