/// Comprehensive global car brand and model data for dropdowns.
///
/// Notes:
/// - Include "Other" in every brand list to allow custom entry.
/// - Brands list also exposes an overall "Other" choice handled in UI.
library car_data;

const String kOtherOption = 'Other';

/// Map of Brand => Clearbit logo URL using the official/global brand domain.
/// Example: 'Toyota' => 'https://logo.clearbit.com/toyota.com'
const Map<String, String> brandLogos = {
  // Japan
  'Toyota': 'https://logo.clearbit.com/toyota.com',
  'Nissan': 'https://logo.clearbit.com/nissan-global.com',
  'Lexus': 'https://logo.clearbit.com/lexus.com',
  'Honda': 'https://logo.clearbit.com/honda.com',
  'Acura': 'https://logo.clearbit.com/acura.com',
  'Mitsubishi': 'https://logo.clearbit.com/mitsubishi-motors.com',
  'Mazda': 'https://logo.clearbit.com/mazda.com',
  'Subaru': 'https://logo.clearbit.com/subaru-global.com',
  'Suzuki': 'https://logo.clearbit.com/suzuki.com',
  'Isuzu': 'https://logo.clearbit.com/isuzu.co.jp',
  'Infiniti': 'https://logo.clearbit.com/infiniti.com',

  // Germany
  'Mercedes-Benz': 'https://logo.clearbit.com/mercedes-benz.com',
  'BMW': 'https://logo.clearbit.com/bmw.com',
  'Audi': 'https://logo.clearbit.com/audi.com',
  'Porsche': 'https://logo.clearbit.com/porsche.com',
  'Volkswagen': 'https://logo.clearbit.com/volkswagen.com',
  'Opel': 'https://logo.clearbit.com/opel.com',

  // UK
  'Land Rover': 'https://logo.clearbit.com/landrover.com',
  'Range Rover': 'https://logo.clearbit.com/landrover.com',
  'Jaguar': 'https://logo.clearbit.com/jaguar.com',
  'Bentley': 'https://logo.clearbit.com/bentleymotors.com',
  'Rolls-Royce': 'https://logo.clearbit.com/rolls-roycemotorcars.com',
  'Aston Martin': 'https://logo.clearbit.com/astonmartin.com',
  'Lotus': 'https://logo.clearbit.com/lotuscars.com',
  'Mini': 'https://logo.clearbit.com/mini.com',

  // Italy
  'Ferrari': 'https://logo.clearbit.com/ferrari.com',
  'Lamborghini': 'https://logo.clearbit.com/lamborghini.com',
  'Maserati': 'https://logo.clearbit.com/maserati.com',
  'Alfa Romeo': 'https://logo.clearbit.com/alfaromeo.com',
  'Fiat': 'https://logo.clearbit.com/fiat.com',

  // France
  'Renault': 'https://logo.clearbit.com/renault.com',
  'Peugeot': 'https://logo.clearbit.com/peugeot.com',
  'Citroen': 'https://logo.clearbit.com/citroen.com',

  // USA
  'Ford': 'https://logo.clearbit.com/ford.com',
  'Chevrolet': 'https://logo.clearbit.com/chevrolet.com',
  'GMC': 'https://logo.clearbit.com/gmc.com',
  'Cadillac': 'https://logo.clearbit.com/cadillac.com',
  'Dodge': 'https://logo.clearbit.com/dodge.com',
  'Jeep': 'https://logo.clearbit.com/jeep.com',
  'Chrysler': 'https://logo.clearbit.com/chrysler.com',
  'Lincoln': 'https://logo.clearbit.com/lincoln.com',
  'Tesla': 'https://logo.clearbit.com/tesla.com',
  'Rivian': 'https://logo.clearbit.com/rivian.com',
  'Lucid': 'https://logo.clearbit.com/lucidmotors.com',

  // Korea
  'Hyundai': 'https://logo.clearbit.com/hyundai.com',
  'Kia': 'https://logo.clearbit.com/kia.com',
  'Genesis': 'https://logo.clearbit.com/genesis.com',

  // China
  'BYD': 'https://logo.clearbit.com/byd.com',
  'Changan': 'https://logo.clearbit.com/changan.com.cn',
  'Geely': 'https://logo.clearbit.com/geely.com',
  'MG': 'https://logo.clearbit.com/mgmotor.eu',
  'Haval': 'https://logo.clearbit.com/haval.com',
  'Great Wall': 'https://logo.clearbit.com/gwm.com.cn',
  'Tank': 'https://logo.clearbit.com/gwm.com.cn',
  'Ora': 'https://logo.clearbit.com/gwm.com.cn',
  'Wey': 'https://logo.clearbit.com/gwm.com.cn',
  'GAC': 'https://logo.clearbit.com/gac-motor.com',
  'Chery': 'https://logo.clearbit.com/cheryglobal.com',
  'Jetour': 'https://logo.clearbit.com/jetour.com',
  'Exeed': 'https://logo.clearbit.com/exeedcars.com',
  'Hongqi': 'https://logo.clearbit.com/hongqi-auto.com',
  'Zeekr': 'https://logo.clearbit.com/zeekr.com',
  'Nio': 'https://logo.clearbit.com/nio.com',
  'Xpeng': 'https://logo.clearbit.com/xpeng.com',
  'Li Auto': 'https://logo.clearbit.com/lixiang.com',
  'Lynk & Co': 'https://logo.clearbit.com/lynkco.com',
  'Omoda': 'https://logo.clearbit.com/omodaauto.com',
  'Jaecoo': 'https://logo.clearbit.com/jaecoo.com',
  'BAIC': 'https://logo.clearbit.com/baicgroup.com.cn',
  'Dongfeng': 'https://logo.clearbit.com/dongfeng-global.com',
  'Forthing': 'https://logo.clearbit.com/dongfeng-global.com',
  'Maxus': 'https://logo.clearbit.com/saicmaxus.com',
  'JAC': 'https://logo.clearbit.com/jac.com.cn',
  'Bestune': 'https://logo.clearbit.com/bestune.com.cn',
  'Wuling': 'https://logo.clearbit.com/sgmw.com.cn',

  // Sweden / Others
  'Volvo': 'https://logo.clearbit.com/volvocars.com',
  'Polestar': 'https://logo.clearbit.com/polestar.com',

  // Spain / Czech
  'Seat': 'https://logo.clearbit.com/seat.com',
  'Skoda': 'https://logo.clearbit.com/skoda-auto.com',
  'Cupra': 'https://logo.clearbit.com/cupraofficial.com',

  // Others / Luxury
  'Smart': 'https://logo.clearbit.com/smart.com',
  'Maybach': 'https://logo.clearbit.com/mercedes-benz.com',
  'McLaren': 'https://logo.clearbit.com/mclaren.com',
  'Bugatti': 'https://logo.clearbit.com/bugatti.com',

  // Commercial & Buses (light)
  'Iveco': 'https://logo.clearbit.com/iveco.com',
  'MAN': 'https://logo.clearbit.com/man.eu',
  'Scania': 'https://logo.clearbit.com/scania.com',
  'Hino': 'https://logo.clearbit.com/hino-global.com',
  'Fuso': 'https://logo.clearbit.com/mitsubishi-fuso.com',
};

/// Get a logo URL for a brand, returns empty string if unknown.
String logoForBrand(String brand) => brandLogos[brand] ?? '';

/// Map of Brand => List of Models
/// Keep brand names in Title Case to match common UAE market naming and the
/// user-requested spellings (Citroen, Skoda, Seat, Mini, etc.).
const Map<String, List<String>> carData = {
  // Japan
  'Toyota': ['Land Cruiser', 'Prado', 'Camry', 'Corolla', 'Yaris', 'RAV4', 'Hilux', 'Fortuner', 'Supra', 'Avalon', 'C-HR', 'Crown', 'Sequoia', 'Tacoma', 'Tundra', '4Runner', kOtherOption],
  'Nissan': ['Patrol', 'Sunny', 'Altima', 'Maxima', 'Kicks', 'X-Trail', 'Pathfinder', 'Armada', 'GT-R', 'Z', '370Z', 'Navara', 'Sentra', 'Tiida', 'Juke', 'Murano', kOtherOption],
  'Lexus': ['LX', 'GX', 'RX', 'NX', 'ES', 'IS', 'LS', 'RC', 'LC', 'UX', kOtherOption],
  'Honda': ['Civic', 'Accord', 'CR-V', 'HR-V', 'Pilot', 'City', 'Odyssey', 'Crosstour', kOtherOption],
  'Acura': ['ILX', 'TLX', 'RLX', 'RDX', 'MDX', 'NSX', kOtherOption],
  'Mitsubishi': ['Pajero', 'Outlander', 'ASX', 'Lancer', 'Attrage', 'Montero Sport', 'Eclipse Cross', kOtherOption],
  'Mazda': ['Mazda2', 'Mazda3', 'Mazda6', 'CX-3', 'CX-5', 'CX-9', 'CX-30', 'MX-5', kOtherOption],
  'Subaru': ['Impreza', 'WRX', 'Forester', 'Outback', 'XV', 'BRZ', kOtherOption],
  'Suzuki': ['Swift', 'Dzire', 'Ciaz', 'Vitara', 'Jimny', 'Baleno', 'Ertiga', kOtherOption],
  'Isuzu': ['D-MAX', 'MU-X', 'N-Series', 'F-Series', kOtherOption],
  'Infiniti': ['Q50', 'Q60', 'QX50', 'QX55', 'QX60', 'QX70', 'QX80', kOtherOption],

  // Germany
  'Mercedes-Benz': ['A-Class', 'C-Class', 'E-Class', 'S-Class', 'G-Class', 'CLA', 'CLS', 'GLA', 'GLB', 'GLC', 'GLE', 'GLS', 'AMG GT', 'V-Class', 'Sprinter', 'EQS', 'EQE', 'EQB', kOtherOption],
  'BMW': ['1 Series', '2 Series', '3 Series', '4 Series', '5 Series', '7 Series', '8 Series', 'X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7', 'M2', 'M3', 'M4', 'M5', 'M8', 'i4', 'i7', 'iX', kOtherOption],
  'Audi': ['A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'Q2', 'Q3', 'Q5', 'Q7', 'Q8', 'TT', 'R8', 'e-tron', 'RS3', 'RS5', 'RS6', 'RS7', kOtherOption],
  'Porsche': ['911', '718 Boxster', '718 Cayman', 'Cayenne', 'Macan', 'Panamera', 'Taycan', kOtherOption],
  'Volkswagen': ['Golf', 'Polo', 'Passat', 'Jetta', 'Tiguan', 'Touareg', 'Arteon', 'ID.4', kOtherOption],
  'Opel': ['Corsa', 'Astra', 'Insignia', 'Mokka', 'Grandland', kOtherOption],

  // UK (including Range Rover per requirement)
  'Land Rover': ['Range Rover', 'Range Rover Sport', 'Range Rover Velar', 'Range Rover Evoque', 'Defender', 'Discovery', 'Discovery Sport', kOtherOption],
  'Range Rover': ['Range Rover', 'Range Rover Sport', 'Range Rover Velar', 'Range Rover Evoque', kOtherOption],
  'Jaguar': ['XE', 'XF', 'XJ', 'F-PACE', 'E-PACE', 'I-PACE', 'F-TYPE', kOtherOption],
  'Bentley': ['Bentayga', 'Continental GT', 'Flying Spur', 'Mulsanne', kOtherOption],
  'Rolls-Royce': ['Phantom', 'Ghost', 'Wraith', 'Dawn', 'Cullinan', kOtherOption],
  'Aston Martin': ['DB11', 'DB12', 'DBS', 'Vantage', 'DBX', 'Rapide', kOtherOption],
  'Lotus': ['Emira', 'Evora', 'Elise', 'Exige', 'Eletre', kOtherOption],
  'Mini': ['3-Door', '5-Door', 'Clubman', 'Countryman', 'Convertible', kOtherOption],

  // Italy
  'Ferrari': ['488', 'F8 Tributo', 'Roma', 'Portofino', 'SF90', '296 GTB', kOtherOption],
  'Lamborghini': ['Huracan', 'Aventador', 'Urus', 'Revuelto', kOtherOption],
  'Maserati': ['Ghibli', 'Quattroporte', 'Levante', 'Grecale', 'MC20', kOtherOption],
  'Alfa Romeo': ['Giulia', 'Giulietta', 'Stelvio', 'Tonale', kOtherOption],
  'Fiat': ['500', '500X', 'Panda', 'Tipo', kOtherOption],

  // France
  'Renault': ['Megane', 'Symbol', 'Clio', 'Koleos', 'Captur', 'Duster', 'Talisman', kOtherOption],
  'Peugeot': ['208', '301', '308', '3008', '5008', '2008', '408', kOtherOption],
  'Citroen': ['C3', 'C4', 'C5 Aircross', 'C-Elysee', kOtherOption],

  // USA
  'Ford': ['Mustang', 'Explorer', 'Expedition', 'Edge', 'Escape', 'F-150', 'Bronco', kOtherOption],
  'Chevrolet': ['Spark', 'Malibu', 'Camaro', 'Traverse', 'Tahoe', 'Suburban', 'Silverado', 'Blazer', kOtherOption],
  'GMC': ['Terrain', 'Acadia', 'Yukon', 'Sierra', 'Canyon', kOtherOption],
  'Cadillac': ['CT4', 'CT5', 'XT4', 'XT5', 'XT6', 'Escalade', kOtherOption],
  'Dodge': ['Charger', 'Challenger', 'Durango', 'Ram', kOtherOption],
  'Jeep': ['Wrangler', 'Grand Cherokee', 'Cherokee', 'Compass', 'Renegade', 'Gladiator', kOtherOption],
  'Chrysler': ['300', 'Pacifica', kOtherOption],
  'Lincoln': ['Aviator', 'Corsair', 'Nautilus', 'Navigator', kOtherOption],
  'Tesla': ['Model S', 'Model 3', 'Model X', 'Model Y', 'Cybertruck', kOtherOption],
  'Rivian': ['R1T', 'R1S', kOtherOption],
  'Lucid': ['Air', 'Gravity', kOtherOption],

  // Korea
  'Hyundai': ['Elantra', 'Sonata', 'Accent', 'Creta', 'Tucson', 'Santa Fe', 'Palisade', 'Kona', 'Staria', kOtherOption],
  'Kia': ['Rio', 'Cerato', 'K5', 'K8', 'Sportage', 'Sorento', 'Telluride', 'Seltos', 'Carnival', kOtherOption],
  'Genesis': ['G70', 'G80', 'G90', 'GV60', 'GV70', 'GV80', kOtherOption],

  // China (explicit per requirement)
  'BYD': ['Atto 3', 'Han', 'Seal', 'Dolphin', 'Tang', 'Song Plus', 'Qin Plus', kOtherOption],
  'Changan': ['Alsvin', 'Eado', 'CS35', 'CS55', 'CS75', 'CS85', 'CS95', 'UNI-T', 'UNI-K', 'UNI-V', 'Hunter', kOtherOption],
  'Geely': ['Coolray', 'Monjaro', 'Tugella', 'Emgrand', 'Okavango', 'Preface', 'Geometry', kOtherOption],
  'MG': ['MG3', 'MG5', 'MG6', 'MG7', 'ZS', 'HS', 'RX5', 'RX8', 'Marvel R', 'Cyberster', kOtherOption],
  'Haval': ['H6', 'H9', 'Jolion', 'Dargo', 'Big Dog', kOtherOption],
  'Great Wall': ['Wingle', 'Poer', 'H5', 'H6', kOtherOption],
  'Tank': ['300', '500', '700', kOtherOption],
  'Ora': ['Good Cat', 'Lightning Cat', kOtherOption],
  'Wey': ['VV7', 'VV5', 'Coffee 01', kOtherOption],
  'GAC': ['GS3', 'GS4', 'GS5', 'GS8', 'GA4', 'GA6', 'GA8', 'Empow', 'M8', kOtherOption],
  'Chery': ['Tiggo 2', 'Tiggo 4', 'Tiggo 7', 'Tiggo 8', 'Arrizo 5', 'Arrizo 6', kOtherOption],
  'Jetour': ['X70', 'X70 Plus', 'X90', 'X90 Plus', 'T2', 'Dashing', kOtherOption],
  'Exeed': ['LX', 'TXL', 'VX', 'RX', kOtherOption],
  'Omoda': ['Omoda 5', 'E5', kOtherOption],
  'Jaecoo': ['J7', 'J8', kOtherOption],
  'Hongqi': ['H5', 'H7', 'H9', 'HS3', 'HS5', 'HS7', 'E-HS9', kOtherOption],
  'Zeekr': ['001', '007', '009', 'X', kOtherOption],
  'Nio': ['ET5', 'ET7', 'ES6', 'ES7', 'ES8', 'EC6', kOtherOption],
  'Xpeng': ['P5', 'P7', 'G3', 'G6', 'G9', kOtherOption],
  'Li Auto': ['L6', 'L7', 'L8', 'L9', 'MEGA', kOtherOption],
  'Lynk & Co': ['01', '02', '03', '05', '09', kOtherOption],
  'BAIC': ['BJ40', 'X7', 'Senova', kOtherOption],
  'Dongfeng': ['Aeolus', 'Fengon', 'Joyear', kOtherOption],
  'Forthing': ['T5', 'T5 EVO', 'M7', kOtherOption],
  'Maxus': ['T60', 'D60', 'G50', 'G10', 'D90', kOtherOption],
  'JAC': ['S3', 'S4', 'S7', 'JS4', 'T8', kOtherOption],
  'Bestune': ['T33', 'T55', 'T77', 'B70', kOtherOption],
  'Wuling': ['Hongguang Mini EV', 'Cortez', 'Confero', kOtherOption],

  // Sweden / Others
  'Volvo': ['S60', 'S90', 'V60', 'XC40', 'XC60', 'XC90', kOtherOption],
  'Polestar': ['2', '3', '4', kOtherOption],

  // Spain / Czech
  'Seat': ['Ibiza', 'Leon', 'Ateca', 'Tarraco', kOtherOption],
  'Skoda': ['Fabia', 'Octavia', 'Superb', 'Karoq', 'Kodiaq', 'Enyaq', kOtherOption],
  'Cupra': ['Leon', 'Formentor', 'Born', 'Ateca', kOtherOption],

  // Others / Luxury
  'Smart': ['Fortwo', 'Forfour', 'Smart #1', 'Smart #3', kOtherOption],
  'Maybach': ['S-Class Maybach', 'GLS Maybach', kOtherOption],
  'McLaren': ['570S', '600LT', '650S', '720S', 'Artura', 'GT', kOtherOption],
  'Bugatti': ['Chiron', 'Divo', 'Centodieci', kOtherOption],

  // Commercial & Buses (light)
  'Iveco': ['Daily', 'Eurocargo', kOtherOption],
  'MAN': ['TGE', 'TGM', 'TGX', kOtherOption],
  'Scania': ['P-Series', 'G-Series', 'R-Series', kOtherOption],
  'Hino': ['300', '500', kOtherOption],
  'Fuso': ['Canter', 'Rosa', kOtherOption],
};

/// Returns a sorted list of brands with stable order.
List<String> getAllBrands({bool includeOther = true}) {
  final list = carData.keys.toList()..sort();
  if (includeOther) list.add(kOtherOption);
  return list;
}

/// Returns models for a brand, always including "Other".
List<String> getModelsForBrand(String brand) {
  if (brand == kOtherOption) return [kOtherOption];
  final models = List<String>.from(carData[brand] ?? const []);
  if (!models.contains(kOtherOption)) models.add(kOtherOption);
  return models;
}
