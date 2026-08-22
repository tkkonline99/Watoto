/// Names for the pictures a choice stage offers, in all three languages.
///
/// A staged choice used to be three bare emoji: 🧑 😠 😊 with nothing written
/// on them. The child could see the pictures but neither they nor the grown-up
/// reading over their shoulder could tell what any option was *called*, which
/// is most of the point on a first-words lesson.
///
/// The words come from [lexicon] in content_lexicon.dart, whose keys are
/// English by construction — the planner scans English narration. Printing a
/// key straight onto a card would put English in front of a Swahili or French
/// child, which the app does not do (see the UI-localization rule in
/// library_play_screen.dart). So every choosable lexicon key is named here in
/// all three languages, and anything not named here shows **no label at all**
/// rather than an English one.
///
/// That silence is deliberate and load-bearing. Reading steps stage minimal
/// pairs — 'cap' against 'cape', 'cepe', 'bookse' — deliberate near-misses that
/// exist only as English letter shapes. There is nothing to translate and
/// nothing to name, and falling back to the key would have printed the nonsense
/// word twice.
///
/// The Swahili and French here are mine and have not been reviewed by a native
/// speaker, in common with the rest of the app's non-English copy.
library;

/// One picture's name in each of the app's languages.
class OptionWord {
  const OptionWord(this.en, this.sw, this.fr);

  final String en;
  final String sw;
  final String fr;

  String forLang(String lang) => switch (lang) {
        'sw' => sw,
        'fr' => fr,
        _ => en,
      };
}

/// The name to write on a pictorial option, or null when there is none.
///
/// Null means "show the picture alone" — never "fall back to English".
String? optionLabel(String word, String lang) {
  final w = word.toLowerCase();

  // "letter A" / "number 13" are built by the planner from a template, so they
  // are named the same way rather than enumerated.
  if (_letter.firstMatch(w) case final m?) {
    return switch (lang) {
      'sw' => 'Herufi ${m.group(1)!.toUpperCase()}',
      'fr' => 'Lettre ${m.group(1)!.toUpperCase()}',
      _ => 'Letter ${m.group(1)!.toUpperCase()}',
    };
  }
  if (_number.firstMatch(w) case final m?) {
    return switch (lang) {
      'sw' => 'Nambari ${m.group(1)}',
      'fr' => 'Numéro ${m.group(1)}',
      _ => 'Number ${m.group(1)}',
    };
  }
  return optionWords[w]?.forLang(lang);
}

final _letter = RegExp(r'^letter ([a-z])$');
final _number = RegExp(r'^number (\d+)$');

/// Every choosable lexicon key, named in English, Swahili and French.
///
/// Grouped the way content_lexicon.dart groups them, because the distractor
/// pool is drawn from a single category — the words that sit next to each
/// other on screen are the words that sit next to each other here, which is
/// what makes a collision like "hat"/"cap" both visible and fixable.
const optionWords = <String, OptionWord>{
  // ---------------------------------------------------------------- animals
  'dog': OptionWord('Dog', 'Mbwa', 'Chien'),
  'puppy': OptionWord('Puppy', 'Mtoto wa mbwa', 'Chiot'),
  'cat': OptionWord('Cat', 'Paka', 'Chat'),
  'kitten': OptionWord('Kitten', 'Mtoto wa paka', 'Chaton'),
  'fish': OptionWord('Fish', 'Samaki', 'Poisson'),
  'bird': OptionWord('Bird', 'Ndege', 'Oiseau'),
  'duck': OptionWord('Duck', 'Bata', 'Canard'),
  'rabbit': OptionWord('Rabbit', 'Sungura', 'Lapin'),
  'bunny': OptionWord('Bunny', 'Sungura', 'Lapin'),
  'bear': OptionWord('Bear', 'Dubu', 'Ours'),
  'lion': OptionWord('Lion', 'Simba', 'Lion'),
  'elephant': OptionWord('Elephant', 'Tembo', 'Éléphant'),
  'cow': OptionWord('Cow', "Ng'ombe", 'Vache'),
  'horse': OptionWord('Horse', 'Farasi', 'Cheval'),
  'pig': OptionWord('Pig', 'Nguruwe', 'Cochon'),
  'sheep': OptionWord('Sheep', 'Kondoo', 'Mouton'),
  'goat': OptionWord('Goat', 'Mbuzi', 'Chèvre'),
  'chicken': OptionWord('Chicken', 'Kuku', 'Poule'),
  'frog': OptionWord('Frog', 'Chura', 'Grenouille'),
  'bee': OptionWord('Bee', 'Nyuki', 'Abeille'),
  'butterfly': OptionWord('Butterfly', 'Kipepeo', 'Papillon'),
  'snake': OptionWord('Snake', 'Nyoka', 'Serpent'),
  'monkey': OptionWord('Monkey', 'Tumbili', 'Singe'),
  'mouse': OptionWord('Mouse', 'Panya', 'Souris'),
  'turtle': OptionWord('Turtle', 'Kobe', 'Tortue'),
  'bug': OptionWord('Bug', 'Mdudu', 'Insecte'),
  'ant': OptionWord('Ant', 'Sisimizi', 'Fourmi'),
  'spider': OptionWord('Spider', 'Buibui', 'Araignée'),
  'crab': OptionWord('Crab', 'Kaa', 'Crabe'),
  'whale': OptionWord('Whale', 'Nyangumi', 'Baleine'),
  'shark': OptionWord('Shark', 'Papa', 'Requin'),
  'octopus': OptionWord('Octopus', 'Pweza', 'Pieuvre'),
  'giraffe': OptionWord('Giraffe', 'Twiga', 'Girafe'),
  'zebra': OptionWord('Zebra', 'Pundamilia', 'Zèbre'),
  'penguin': OptionWord('Penguin', 'Pengwini', 'Manchot'),
  'owl': OptionWord('Owl', 'Bundi', 'Hibou'),
  'fox': OptionWord('Fox', 'Mbweha', 'Renard'),
  'deer': OptionWord('Deer', 'Kulungu', 'Cerf'),
  'wolf': OptionWord('Wolf', 'Mbwa mwitu', 'Loup'),
  'tiger': OptionWord('Tiger', 'Simbamarara', 'Tigre'),
  'hippo': OptionWord('Hippo', 'Kiboko', 'Hippopotame'),
  'snail': OptionWord('Snail', 'Konokono', 'Escargot'),
  'worm': OptionWord('Worm', 'Mnyoo', 'Ver'),
  'kangaroo': OptionWord('Kangaroo', 'Kangaruu', 'Kangourou'),
  'gecko': OptionWord('Gecko', 'Mjusi', 'Gecko'),
  'lizard': OptionWord('Lizard', 'Mjusi', 'Lézard'),

  // --------------------------------------------------------------- clothing
  'hat': OptionWord('Hat', 'Kofia', 'Chapeau'),
  'shoe': OptionWord('Shoe', 'Kiatu', 'Chaussure'),
  'shirt': OptionWord('Shirt', 'Shati', 'Chemise'),
  'sock': OptionWord('Sock', 'Soksi', 'Chaussette'),
  'coat': OptionWord('Coat', 'Koti', 'Manteau'),
  'jacket': OptionWord('Jacket', 'Jaketi', 'Veste'),
  'dress': OptionWord('Dress', 'Gauni', 'Robe'),
  'pants': OptionWord('Trousers', 'Suruali', 'Pantalon'),
  'boot': OptionWord('Boot', 'Buti', 'Botte'),
  'scarf': OptionWord('Scarf', 'Skafu', 'Écharpe'),
  'glove': OptionWord('Glove', 'Glavu', 'Gant'),
  'cap': OptionWord('Cap', 'Kepi', 'Casquette'),
  'helmet': OptionWord('Helmet', 'Helmeti', 'Casque'),

  // ----------------------------------------------------------------- colours
  'red': OptionWord('Red', 'Nyekundu', 'Rouge'),
  'blue': OptionWord('Blue', 'Bluu', 'Bleu'),
  'yellow': OptionWord('Yellow', 'Njano', 'Jaune'),
  'green': OptionWord('Green', 'Kijani', 'Vert'),
  'orange': OptionWord('Orange', 'Chungwa', 'Orange'),
  'purple': OptionWord('Purple', 'Zambarau', 'Violet'),

  // ---------------------------------------------------------------- numbers
  'two': OptionWord('Two', 'Mbili', 'Deux'),
  'three': OptionWord('Three', 'Tatu', 'Trois'),
  'four': OptionWord('Four', 'Nne', 'Quatre'),
  'five': OptionWord('Five', 'Tano', 'Cinq'),
  'six': OptionWord('Six', 'Sita', 'Six'),
  'seven': OptionWord('Seven', 'Saba', 'Sept'),
  'eight': OptionWord('Eight', 'Nane', 'Huit'),
  'nine': OptionWord('Nine', 'Tisa', 'Neuf'),
  'ten': OptionWord('Ten', 'Kumi', 'Dix'),

  // ------------------------------------------------------------- directions
  'north': OptionWord('North', 'Kaskazini', 'Nord'),
  'south': OptionWord('South', 'Kusini', 'Sud'),
  'east': OptionWord('East', 'Mashariki', 'Est'),
  'west': OptionWord('West', 'Magharibi', 'Ouest'),

  // ------------------------------------------------------------------- food
  'apple': OptionWord('Apple', 'Tufaha', 'Pomme'),
  'apples': OptionWord('Apples', 'Matufaha', 'Pommes'),
  'banana': OptionWord('Banana', 'Ndizi', 'Banane'),
  'mango': OptionWord('Mango', 'Embe', 'Mangue'),
  'bread': OptionWord('Bread', 'Mkate', 'Pain'),
  'egg': OptionWord('Egg', 'Yai', 'Œuf'),
  'milk': OptionWord('Milk', 'Maziwa', 'Lait'),
  'cake': OptionWord('Cake', 'Keki', 'Gâteau'),
  'cookie': OptionWord('Biscuit', 'Biskuti', 'Biscuit'),
  'pizza': OptionWord('Pizza', 'Piza', 'Pizza'),
  'carrot': OptionWord('Carrot', 'Karoti', 'Carotte'),
  'corn': OptionWord('Corn', 'Mahindi', 'Maïs'),
  'soup': OptionWord('Soup', 'Supu', 'Soupe'),

  // ----------------------------------------------------------------- nature
  'island': OptionWord('Island', 'Kisiwa', 'Île'),
  'sea': OptionWord('Sea', 'Bahari', 'Mer'),
  'season': OptionWord('Season', 'Msimu', 'Saison'),
  'nest': OptionWord('Nest', 'Kiota', 'Nid'),
  'puddle': OptionWord('Puddle', 'Kidimbwi', 'Flaque'),
  'breeze': OptionWord('Breeze', 'Upepo', 'Brise'),
  'sun': OptionWord('Sun', 'Jua', 'Soleil'),
  'moon': OptionWord('Moon', 'Mwezi', 'Lune'),
  'star': OptionWord('Star', 'Nyota', 'Étoile'),
  'stars': OptionWord('Stars', 'Nyota', 'Étoiles'),
  'tree': OptionWord('Tree', 'Mti', 'Arbre'),
  'flower': OptionWord('Flower', 'Ua', 'Fleur'),
  'grass': OptionWord('Grass', 'Nyasi', 'Herbe'),
  'leaf': OptionWord('Leaf', 'Jani', 'Feuille'),
  'rain': OptionWord('Rain', 'Mvua', 'Pluie'),
  'cloud': OptionWord('Cloud', 'Wingu', 'Nuage'),
  'snow': OptionWord('Snow', 'Theluji', 'Neige'),
  'ice': OptionWord('Ice', 'Barafu', 'Glace'),
  'water': OptionWord('Water', 'Maji', 'Eau'),
  'fire': OptionWord('Fire', 'Moto', 'Feu'),
  'rock': OptionWord('Rock', 'Mwamba', 'Rocher'),
  'mountain': OptionWord('Mountain', 'Mlima', 'Montagne'),
  'river': OptionWord('River', 'Mto', 'Rivière'),
  'ocean': OptionWord('Ocean', 'Bahari', 'Océan'),
  'earth': OptionWord('Earth', 'Dunia', 'Terre'),
  'plant': OptionWord('Plant', 'Mmea', 'Plante'),
  'seed': OptionWord('Seed', 'Mbegu', 'Graine'),
  'rainbow': OptionWord('Rainbow', 'Upinde wa mvua', 'Arc-en-ciel'),
  'sky': OptionWord('Sky', 'Anga', 'Ciel'),
  'night': OptionWord('Night', 'Usiku', 'Nuit'),
  'shell': OptionWord('Shell', 'Kombe', 'Coquillage'),
  'spring': OptionWord('Spring', 'Majira ya kuchipua', 'Printemps'),
  'summer': OptionWord('Summer', 'Kiangazi', 'Été'),
  'fall': OptionWord('Autumn', 'Vuli', 'Automne'),
  'autumn': OptionWord('Autumn', 'Vuli', 'Automne'),
  'winter': OptionWord('Winter', 'Kipupwe', 'Hiver'),
  'shadow': OptionWord('Shadow', 'Kivuli', 'Ombre'),
  'fossil': OptionWord('Fossil', 'Kisukuku', 'Fossile'),
  'planet': OptionWord('Planet', 'Sayari', 'Planète'),
  'jupiter': OptionWord('Jupiter', 'Mshtarii', 'Jupiter'),
  'saturn': OptionWord('Saturn', 'Zohali', 'Saturne'),
  'steam': OptionWord('Steam', 'Mvuke', 'Vapeur'),
  'garden': OptionWord('Garden', 'Bustani', 'Jardin'),
  'jungle': OptionWord('Jungle', 'Msitu', 'Jungle'),
  'beach': OptionWord('Beach', 'Ufuo', 'Plage'),

  // ---------------------------------------------------------------- objects
  'ball': OptionWord('Ball', 'Mpira', 'Ballon'),
  'balloon': OptionWord('Balloon', 'Puto', 'Ballon gonflable'),
  'box': OptionWord('Box', 'Sanduku', 'Boîte'),
  'cup': OptionWord('Cup', 'Kikombe', 'Tasse'),
  'spoon': OptionWord('Spoon', 'Kijiko', 'Cuillère'),
  'book': OptionWord('Book', 'Kitabu', 'Livre'),
  'books': OptionWord('Books', 'Vitabu', 'Livres'),
  'pencil': OptionWord('Pencil', 'Penseli', 'Crayon'),
  'crayon': OptionWord('Crayon', 'Kalamu ya rangi', 'Crayon de couleur'),
  'drum': OptionWord('Drum', 'Ngoma', 'Tambour'),
  'bell': OptionWord('Bell', 'Kengele', 'Cloche'),
  'robot': OptionWord('Robot', 'Roboti', 'Robot'),
  'computer': OptionWord('Computer', 'Kompyuta', 'Ordinateur'),
  'phone': OptionWord('Phone', 'Simu', 'Téléphone'),
  'clock': OptionWord('Clock', 'Saa', 'Horloge'),
  'key': OptionWord('Key', 'Ufunguo', 'Clé'),
  'paper': OptionWord('Paper', 'Karatasi', 'Papier'),
  'towel': OptionWord('Towel', 'Taulo', 'Serviette'),
  'blanket': OptionWord('Blanket', 'Blanketi', 'Couverture'),
  'pot': OptionWord('Pot', 'Sufuria', 'Casserole'),
  'shelf': OptionWord('Shelf', 'Rafu', 'Étagère'),
  'gift': OptionWord('Gift', 'Zawadi', 'Cadeau'),
  'window': OptionWord('Window', 'Dirisha', 'Fenêtre'),
  'plate': OptionWord('Plate', 'Sahani', 'Assiette'),
  'lid': OptionWord('Lid', 'Mfuniko', 'Couvercle'),
  'basket': OptionWord('Basket', 'Kikapu', 'Panier'),
  'door': OptionWord('Door', 'Mlango', 'Porte'),
  'bed': OptionWord('Bed', 'Kitanda', 'Lit'),
  'chair': OptionWord('Chair', 'Kiti', 'Chaise'),
  'toy': OptionWord('Toy', 'Kichezeo', 'Jouet'),
  'doll': OptionWord('Doll', 'Mwanasesere', 'Poupée'),
  'block': OptionWord('Block', 'Bloku', 'Bloc'),
  'blocks': OptionWord('Blocks', 'Bloku', 'Blocs'),
  'rattle': OptionWord('Rattle', 'Njuga', 'Hochet'),
  'kite': OptionWord('Kite', 'Tiara', 'Cerf-volant'),
  'umbrella': OptionWord('Umbrella', 'Mwavuli', 'Parapluie'),
  'magnet': OptionWord('Magnet', 'Sumaku', 'Aimant'),
  'coin': OptionWord('Coin', 'Sarafu', 'Pièce'),
  'coins': OptionWord('Coins', 'Sarafu', 'Pièces'),
  'flag': OptionWord('Flag', 'Bendera', 'Drapeau'),
  'map': OptionWord('Map', 'Ramani', 'Carte'),
  'car': OptionWord('Car', 'Gari', 'Voiture'),
  'bus': OptionWord('Bus', 'Basi', 'Bus'),
  'train': OptionWord('Train', 'Treni', 'Train'),
  'boat': OptionWord('Boat', 'Mashua', 'Bateau'),
  'plane': OptionWord('Plane', 'Ndege', 'Avion'),
  'bike': OptionWord('Bike', 'Baiskeli', 'Vélo'),
  'wheel': OptionWord('Wheel', 'Gurudumu', 'Roue'),
  'bubble': OptionWord('Bubble', 'Kiputo', 'Bulle'),
  'bubbles': OptionWord('Bubbles', 'Viputo', 'Bulles'),
  'cube': OptionWord('Cube', 'Mchemraba', 'Cube'),
  'curtains': OptionWord('Curtains', 'Mapazia', 'Rideaux'),
  'puzzle': OptionWord('Puzzle', 'Fumbo', 'Puzzle'),
  'globe': OptionWord('Globe', 'Tufe', 'Globe'),
  'lamp': OptionWord('Lamp', 'Taa', 'Lampe'),
  'pen': OptionWord('Pen', 'Kalamu', 'Stylo'),
  'quill': OptionWord('Quill', 'Kalamu ya manyoya', 'Plume'),
  'bin': OptionWord('Bin', 'Pipa', 'Poubelle'),
  'den': OptionWord('Den', 'Pango', 'Tanière'),
  'wood': OptionWord('Wood', 'Mbao', 'Bois'),
  'shaker': OptionWord('Shaker', 'Kayamba', 'Maracas'),
  'paperclip': OptionWord('Paperclip', 'Klipu', 'Trombone'),
  'house': OptionWord('House', 'Nyumba', 'Maison'),
  'home': OptionWord('Home', 'Nyumbani', 'Foyer'),
  'school': OptionWord('School', 'Shule', 'École'),
  'farm': OptionWord('Farm', 'Shamba', 'Ferme'),
  'zoo': OptionWord('Zoo', 'Mbuga ya wanyama', 'Zoo'),
  'store': OptionWord('Shop', 'Duka', 'Magasin'),
  'street': OptionWord('Street', 'Barabara', 'Rue'),

  // ----------------------------------------------------------------- people
  'job': OptionWord('Worker', 'Mfanyakazi', 'Ouvrier'),
  'head': OptionWord('Head', 'Kichwa', 'Tête'),
  'lips': OptionWord('Lips', 'Midomo', 'Lèvres'),
  'hug': OptionWord('Hug', 'Kumbatio', 'Câlin'),
  'doctor': OptionWord('Doctor', 'Daktari', 'Médecin'),
  'firefighter': OptionWord('Firefighter', 'Mzima moto', 'Pompier'),
  'teacher': OptionWord('Teacher', 'Mwalimu', 'Maître'),
  'farmer': OptionWord('Farmer', 'Mkulima', 'Fermier'),
  'baby': OptionWord('Baby', 'Mtoto mchanga', 'Bébé'),
  'family': OptionWord('Family', 'Familia', 'Famille'),
  'friend': OptionWord('Friend', 'Rafiki', 'Ami'),
  'friends': OptionWord('Friends', 'Marafiki', 'Amis'),
  'mom': OptionWord('Mum', 'Mama', 'Maman'),
  'mama': OptionWord('Mum', 'Mama', 'Maman'),
  'dad': OptionWord('Dad', 'Baba', 'Papa'),
  'dada': OptionWord('Dad', 'Baba', 'Papa'),
  'grown': OptionWord('Grown-up', 'Mtu mzima', 'Adulte'),
  'parent': OptionWord('Parent', 'Mzazi', 'Parent'),
  'girl': OptionWord('Girl', 'Msichana', 'Fille'),
  'boy': OptionWord('Boy', 'Mvulana', 'Garçon'),
  'mayor': OptionWord('Mayor', 'Meya', 'Maire'),
  'happy': OptionWord('Happy', 'Mwenye furaha', 'Content'),
  'smiling': OptionWord('Smiling', 'Anayetabasamu', 'Souriant'),
  'sad': OptionWord('Sad', 'Mwenye huzuni', 'Triste'),
  'angry': OptionWord('Cross', 'Mwenye hasira', 'Fâché'),
  'scared': OptionWord('Scared', 'Mwenye hofu', 'Effrayé'),
  'excited': OptionWord('Excited', 'Mwenye shauku', 'Excité'),
  'sleepy': OptionWord('Sleepy', 'Mwenye usingizi', 'Endormi'),
  'proud': OptionWord('Proud', 'Mwenye fahari', 'Fier'),
  'frustrated': OptionWord('Frustrated', 'Mwenye kufadhaika', 'Agacé'),
  'worried': OptionWord('Worried', 'Mwenye wasiwasi', 'Inquiet'),
  'toes': OptionWord('Toes', 'Vidole vya mguu', 'Orteils'),
  'lungs': OptionWord('Lungs', 'Mapafu', 'Poumons'),
  'eyes': OptionWord('Eyes', 'Macho', 'Yeux'),
  'eye': OptionWord('Eye', 'Jicho', 'Œil'),
  'nose': OptionWord('Nose', 'Pua', 'Nez'),
  'mouth': OptionWord('Mouth', 'Mdomo', 'Bouche'),
  'ear': OptionWord('Ear', 'Sikio', 'Oreille'),
  'hand': OptionWord('Hand', 'Mkono', 'Main'),
  'hands': OptionWord('Hands', 'Mikono', 'Mains'),
  'foot': OptionWord('Foot', 'Mguu', 'Pied'),
  'teeth': OptionWord('Teeth', 'Meno', 'Dents'),

  // ----------------------------------------------------------------- shapes
  'heart': OptionWord('Heart', 'Moyo', 'Cœur'),
  'circle': OptionWord('Circle', 'Duara', 'Cercle'),
  'square': OptionWord('Square', 'Mraba', 'Carré'),
  'triangle': OptionWord('Triangle', 'Pembetatu', 'Triangle'),
  'diamond': OptionWord('Diamond', 'Almasi', 'Losange'),

  // -------------------------------------------------------------- opposites
  // Staged in pairs by `_oppositePlan` rather than drawn from the lexicon, so
  // these keys live outside the categories above.
  'big': OptionWord('Big', 'Kubwa', 'Grand'),
  'small': OptionWord('Small', 'Ndogo', 'Petit'),
  'hot': OptionWord('Hot', 'Moto', 'Chaud'),
  'cold': OptionWord('Cold', 'Baridi', 'Froid'),
  'fast': OptionWord('Fast', 'Haraka', 'Rapide'),
  'slow': OptionWord('Slow', 'Polepole', 'Lent'),
  'up': OptionWord('Up', 'Juu', 'En haut'),
  'down': OptionWord('Down', 'Chini', 'En bas'),

  // ----------------------------------------------------------- punctuation
  // Named by the planner's `_punctuation` table, so these keys are phrases
  // rather than single words.
  'comma': OptionWord('Comma', 'Mkato', 'Virgule'),
  'period': OptionWord('Full stop', 'Nukta', 'Point'),
  'question mark':
      OptionWord('Question mark', 'Alama ya kuuliza', "Point d'interrogation"),
  'exclamation mark':
      OptionWord('Exclamation mark', 'Alama ya mshangao', "Point d'exclamation"),
  'quotation mark':
      OptionWord('Quotation mark', 'Alama ya kunukuu', 'Guillemet'),
};
