local Names = {}

Names.gangLabels = {
    Maelstrom = "Maelstrom",
    TygerClaws = "Tyger Claws",
    Valentinos = "Valentinos",
    SixthStreet = "6th Street",
    Animals = "Animals",
    VoodooBoys = "Voodoo Boys",
    Wraiths = "Wraiths",
    Scavengers = "Scavs",
    Barghest = "Barghest",
}

local pools = {
    Maelstrom = {
        style = "handle",
        handles = {
            "Static", "Gristle", "Socket", "Torque", "Scrap", "Hex", "Volt", "Rust", "Grinder", "Patch",
            "Glitch", "Rivet", "Servo", "Cathode", "Ferrum", "Null", "Sprocket", "Wirecutter", "Spark", "Bolt",
            "Cinch", "Solder", "Cleaver", "Slag", "Ratchet", "Crank", "Chop", "Gauge", "Splice", "Burr",
            "Weld", "Fuse", "Flange", "Clamp", "Piston", "Shim", "Hacksaw", "Jolt", "Rotor", "Capstan",
            "Dynamo", "Spindle", "Gasket", "Anvil",
        },
    },
    TygerClaws = {
        style = "full",
        male = {
            "Kenji", "Hiro", "Daisuke", "Ryo", "Takeshi", "Akira", "Jin", "Shun", "Kaito", "Wei",
            "Haruto", "Sora", "Ren", "Takumi", "Yuto", "Satoshi", "Masaru", "Goro", "Taro", "Isamu",
            "Noboru", "Kazuo", "Shin", "Tatsuya", "Hideo", "Yoshi", "Koji", "Naoki", "Minato", "Riku",
            "Toshiro", "Genji", "Hayato", "Daichi", "Ken", "Shinji", "Tetsuo", "Jun", "Kenta", "Ryu",
            "Sho", "Eiji", "Masato", "Osamu",
        },
        female = {
            "Mei", "Yuki", "Aiko", "Rin", "Hana", "Sakura", "Lian", "Emi", "Akemi", "Haruka",
            "Miyu", "Yui", "Nao", "Saki", "Kaede", "Ayame", "Reiko", "Chiyo", "Keiko", "Noriko",
            "Sayuri", "Tomoe", "Mio", "Kasumi", "Natsuki", "Ayumi", "Michiko", "Setsuko", "Yoko", "Fumiko",
            "Asuka", "Hikari", "Kimiko", "Madoka", "Miku", "Nanami", "Rika", "Shiori", "Tsubaki", "Suzu",
            "Kyoko", "Chihiro", "Momo", "Ume",
        },
        last = {
            "Mori", "Tanaka", "Ono", "Sato", "Kato", "Ito", "Nakamura", "Kobayashi", "Watanabe", "Hayashi",
            "Suzuki", "Takahashi", "Yamamoto", "Yamada", "Matsumoto", "Inoue", "Kimura", "Shimizu", "Yamaguchi", "Saito",
            "Yoshida", "Sasaki", "Abe", "Ikeda", "Hashimoto", "Ishikawa", "Ogawa", "Goto", "Okada", "Hasegawa",
            "Murakami", "Kondo", "Maeda", "Fujita", "Endo", "Aoki", "Fujii", "Nishimura", "Fukuda", "Ota",
            "Miura", "Takeda", "Ueda", "Harada", "Kuroda",
        },
    },
    Valentinos = {
        style = "full",
        male = {
            "Javier", "Mateo", "Diego", "Luis", "Rafael", "Esteban", "Paco", "Joaquín", "Ramón", "Héctor",
            "Carlos", "Miguel", "Alejandro", "Santiago", "Emilio", "Raúl", "Enrique", "Fernando", "Jorge", "Andrés",
            "Tomás", "Ernesto", "Gabriel", "Hugo", "Ignacio", "Julio", "Lorenzo", "Manuel", "Nicolás", "Óscar",
            "Pablo", "Rodrigo", "Sergio", "Víctor", "Armando", "Alonso", "Benito", "César", "Cristóbal", "Felipe",
            "Gustavo", "Iván", "Leandro", "Marcos", "Octavio", "Ricardo",
        },
        female = {
            "Rosa", "Carmen", "Lupe", "Marisol", "Ximena", "Paloma", "Inés", "Dolores", "Lucía", "Elena",
            "Isabel", "Catalina", "Esperanza", "Guadalupe", "Soledad", "Beatriz", "Camila", "Consuelo", "Graciela", "Josefina",
            "Luz", "Mercedes", "Pilar", "Rocío", "Teresa", "Valentina", "Yolanda", "Adriana", "Alma", "Amparo",
            "Araceli", "Blanca", "Cecilia", "Daniela", "Fernanda", "Gloria", "Imelda", "Leticia", "Lourdes", "Magdalena",
            "Natalia", "Perla", "Reina", "Silvia", "Socorro", "Verónica", "Xóchitl", "Zulema",
        },
        last = {
            "Ortega", "Navarro", "Morales", "Reyes", "Castillo", "Vargas", "Delgado", "Fuentes", "Ibarra", "Salazar",
            "García", "Rodríguez", "Martínez", "López", "Hernández", "Gómez", "Díaz", "Torres", "Ramírez", "Flores",
            "Rivera", "Cruz", "Herrera", "Medina", "Aguilar", "Guerrero", "Mendoza", "Rojas", "Silva", "Soto",
            "Cabrera", "Campos", "Cortés", "Domínguez", "Estrada", "Figueroa", "Guzmán", "Jiménez", "Lara", "Luna",
            "Maldonado", "Montoya", "Peña", "Quintero", "Rangel", "Sandoval", "Téllez", "Valdez", "Zamora", "Ayala",
        },
    },
    SixthStreet = {
        style = "full",
        male = {
            "Hank", "Cole", "Travis", "Wade", "Jesse", "Dale", "Buck", "Clint", "Earl", "Rusty",
            "Walt", "Duke", "Cody", "Bo", "Wyatt", "Cal", "Chet", "Dwight", "Gus", "Hal",
            "Jed", "Lyle", "Merle", "Ned", "Otis", "Roy", "Shane", "Tex", "Virgil", "Zeke",
            "Boone", "Dean", "Elmer", "Floyd", "Garrett", "Hollis", "Jake", "Lonnie", "Mack", "Orville",
            "Percy", "Randall", "Troy", "Vince", "Cletus", "Bubba",
        },
        female = {
            "Carla", "Dottie", "Jolene", "Tammy", "Reba", "Darla", "Wanda", "Lacey", "Loretta", "Peggy",
            "Sue", "Betty", "Dolly", "Shelby", "Tina", "Crystal", "Misty", "Bonnie", "Charlene", "Cheryl",
            "Dixie", "Erin", "Fern", "Gail", "Hattie", "Ida", "Jo", "Kitty", "Lou", "Mabel",
            "Nell", "Opal", "Patsy", "Ruby", "Sherry", "Trixie", "Vicki", "Wilma", "Mavis", "Lorna",
            "Pearl", "Roxanne", "Sally", "Tanya", "Velma", "Marlene", "Candy", "Joanie",
        },
        last = {
            "Dawson", "Brennan", "Hart", "Miller", "Boyd", "Tucker", "Hayes", "Colt", "Pruitt", "Rhodes",
            "Callahan", "Sullivan", "Walker", "Cooper", "Mercer", "Calhoun", "Granger", "Harlan", "Jennings", "Kincaid",
            "Lawson", "McCoy", "Nash", "Overton", "Parrish", "Quinn", "Ramsey", "Sawyer", "Thorne", "Underwood",
            "Vance", "Whitaker", "Yates", "Abbott", "Bridges", "Carver", "Dillard", "Eastman", "Fletcher", "Gentry",
            "Holloway", "Jessup", "Kendrick", "Landry", "McAllister", "Norris", "Pike", "Radcliffe", "Stone", "Wheeler",
        },
    },
    Animals = {
        style = "handle",
        handles = {
            "Tank", "Bruiser", "Ox", "Mauler", "Bull", "Grizzly", "Rhino", "Boar", "Bison", "Gorilla",
            "Brick", "Hammerhead", "Moose", "Mastiff", "Behemoth", "Bear", "Wolverine", "Hog", "Mammoth", "Buffalo",
            "Warthog", "Crusher", "Hippo", "Yak", "Boulder", "Sledge", "Gator", "Croc", "Bulldog", "Pitbull",
            "Walrus", "Elephant", "Kodiak", "Stampede", "Wrecker", "Lug", "Brute", "Hulk", "Ram", "Stag",
            "Jackal", "Gnasher", "Thump", "Colossus", "Titan",
        },
    },
    VoodooBoys = {
        style = "full",
        male = {
            "Marcel", "Toussaint", "Lucien", "Emmanuel", "Gérard", "Fritz", "Ti-Jean", "Wilner", "Jean-Baptiste", "Jean-Claude",
            "Jean-Robert", "Jean-Marc", "Ti-Paul", "Ti-Marc", "Dieudonné", "Jacques", "Josué", "Frantz", "Jonas", "Wesley",
            "Woodley", "Yvon", "Évens", "Gesner", "Edner", "Élie", "Hérard", "Isnel", "Jeanty", "Lucson",
            "Néhémie", "Patrice", "Réginald", "Ronald", "Samuel", "Dumarsais", "Ernst", "Fedner", "Guy", "Hervé",
            "Ismaël", "Kervens", "Lamarre", "Monès", "Ulrick", "Wilfrid", "Yves",
        },
        female = {
            "Celestine", "Fabienne", "Marie-Ange", "Yolande", "Nadège", "Odette", "Marie-Claire", "Marie-Rose", "Marie-Josée", "Ti-Rose",
            "Mireille", "Ginette", "Rosemène", "Esther", "Judith", "Guerda", "Myrlande", "Carline", "Danielle", "Edeline",
            "Fabiola", "Gisèle", "Immacula", "Jocelyne", "Kettly", "Magalie", "Naomie", "Pascale", "Rachelle", "Stéphanie",
            "Tatiana", "Vanessa", "Wislande", "Yvrose", "Zita", "Anaïse", "Béatrice", "Cléonise", "Darline", "Éliane",
            "Flore", "Gertrude", "Hélène", "Ivonne", "Josette", "Laure",
        },
        last = {
            "Duval", "Joseph", "Pierre", "Laurent", "Baptiste", "Dorvil", "Saint-Fleur", "Désir", "Jean", "Louis",
            "Charles", "Étienne", "Paul", "François", "Michel", "Jérôme", "Alexandre", "Antoine", "Augustin", "Bazile",
            "Beauvais", "Bellevue", "Célestin", "Charlemagne", "Cadet", "Delva", "Dumas", "Exantus", "Fils-Aimé", "Gaspard",
            "Guillaume", "Hippolyte", "Jeudy", "Lafortune", "Mathurin", "Noël", "Occident", "Philippe", "Saintil", "Thélusma",
            "Valcourt", "Vilsaint", "Zamor", "Auguste", "Bien-Aimé", "Cinéus", "Desrosiers",
        },
    },
    Wraiths = {
        style = "handle",
        handles = {
            "Dust", "Vulture", "Ash", "Coyote", "Grit", "Rattler", "Buzzard", "Cinder", "Hollow", "Drifter",
            "Bonesaw", "Mirage", "Scorpion", "Sidewinder", "Tumbleweed", "Mesa", "Dune", "Sandstorm", "Jackrabbit", "Gila",
            "Carrion", "Canyon", "Dust Devil", "Sunburn", "Parch", "Thirst", "Salt", "Bleach", "Bones", "Kestrel",
            "Hawk", "Cactus", "Sage", "Scorch", "Haze", "Nomad", "Outrider", "Raven", "Skinner", "Viper",
            "Cutter", "Ember", "Tarantula", "Mange", "Gulch", "Flint", "Husk", "Sinew",
        },
    },
    Scavengers = {
        style = "full",
        male = {
            "Dmitri", "Yuri", "Oleg", "Pavel", "Sergei", "Boris", "Anatoly", "Grigori", "Ivan", "Nikolai",
            "Alexei", "Andrei", "Vladimir", "Maxim", "Konstantin", "Leonid", "Mikhail", "Igor", "Gennady", "Fyodor",
            "Stanislav", "Vasily", "Roman", "Rostislav", "Timur", "Arkady", "Bogdan", "Denis", "Evgeny", "Gleb",
            "Ilya", "Kirill", "Lev", "Matvei", "Nikita", "Pyotr", "Ruslan", "Semyon", "Taras", "Vadim",
            "Vlad", "Yaroslav", "Zakhar", "Artyom", "Anton", "Valentin",
        },
        female = {
            "Olga", "Irina", "Katya", "Svetlana", "Nadia", "Vera", "Natasha", "Tatiana", "Anastasia", "Ekaterina",
            "Galina", "Larisa", "Lyudmila", "Marina", "Oksana", "Polina", "Raisa", "Sofia", "Tamara", "Ulyana",
            "Yelena", "Zoya", "Alina", "Daria", "Elizaveta", "Inna", "Karina", "Liza", "Masha", "Nina",
            "Pelageya", "Sasha", "Varvara", "Yulia", "Agafya", "Bronislava", "Dasha", "Evgenia", "Faina", "Glafira",
            "Klavdia", "Lidia", "Mila", "Nastya", "Ksenia",
        },
        last = {
            "Volkov", "Sokolov", "Petrov", "Morozov", "Kuznetsov", "Lebedev", "Orlov", "Zaitsev", "Ivanov", "Smirnov",
            "Popov", "Vasiliev", "Novikov", "Fyodorov", "Mikhailov", "Belov", "Medvedev", "Alexeyev", "Egorov", "Kozlov",
            "Stepanov", "Nikolaev", "Sorokin", "Romanov", "Vorobyov", "Pavlov", "Semyonov", "Golubev", "Vinogradov", "Bogdanov",
            "Vorontsov", "Tarasov", "Belyaev", "Komarov", "Kiselyov", "Ilyin", "Gusev", "Titov", "Kuzmin", "Kudryavtsev",
            "Baranov", "Kulikov", "Zhukov", "Frolov", "Zimin", "Melnikov", "Sidorov",
        },
    },
    Barghest = {
        style = "full",
        male = {
            "Kurt", "Malik", "Rhys", "Tariq", "Viktor", "Dario", "Emeka", "Hassan", "Marcus", "Jonas",
            "Lars", "Anders", "Declan", "Callum", "Ewan", "Sven", "Matteo", "Luca", "Karim", "Omar",
            "Yusuf", "Idris", "Kwame", "Kofi", "Chidi", "Tomasz", "Marek", "Stefan", "Dragan", "Nikola",
            "Milan", "Henrik", "Jakob", "Ahmed", "Samir", "Faisal", "Jamal", "Bashir", "Tiago", "Nils",
            "Mikkel", "Ibrahim", "Gareth", "Owen", "Connor", "Dominic", "Hendrik",
        },
        female = {
            "Nadia", "Leyla", "Ingrid", "Amara", "Zara", "Freya", "Astrid", "Sigrid", "Helga", "Greta",
            "Katarina", "Mirela", "Ivana", "Magda", "Aisha", "Fatima", "Yasmin", "Samira", "Nneka", "Adaeze",
            "Zainab", "Amina", "Efua", "Abena", "Chiara", "Giulia", "Carys", "Ffion", "Siobhan", "Niamh",
            "Maeve", "Saoirse", "Kirsten", "Annika", "Linnea", "Maja", "Dalia", "Rania", "Noor", "Soraya",
            "Halima", "Imani", "Thandiwe", "Ayanna", "Bronwen",
        },
        last = {
            "Hale", "Osei", "Calder", "Brandt", "Haddad", "Kovač", "Mensah", "Ruiz", "Okafor", "Adeyemi",
            "Nasser", "Karimi", "Rahman", "Farouk", "Novak", "Horvat", "Petrović", "Lindqvist", "Johansen", "Eriksson",
            "Larsen", "Becker", "Krüger", "Schmidt", "Weber", "Fischer", "Rossi", "Ferrari", "Bianchi", "Moreau",
            "Dubois", "Costa", "Pereira", "Murphy", "Gallagher", "MacLeod", "Ashworth", "Whitlock", "Pryce", "Draper",
            "Harker", "Kessler", "Vogel", "Stahl", "Reinhardt", "Amadi", "Boateng", "Danso",
        },
    },
}

local titles = {
    escaped = {
        { en = "the Survivor", es = "el Superviviente", es_f = "la Superviviente" },
        { en = "Scarface", es = "Caracortada" },
        { en = "the Runner", es = "el Fugitivo", es_f = "la Fugitiva" },
        { en = "the Unkillable", es = "el Inmortal", es_f = "la Inmortal" },
        { en = "Lucky", es = "el Suertudo", es_f = "la Suertuda" },
        { en = "Patchwork", es = "el Remendado", es_f = "la Remendada" },
        { en = "the Rat", es = "la Rata" },
        { en = "Half-Dead", es = "Medio Muerto", es_f = "Medio Muerta" },
        { en = "the Grudge", es = "el Rencoroso", es_f = "la Rencorosa" },
        { en = "Nine Lives", es = "Nueve Vidas" },
        { en = "the Cockroach", es = "la Cucaracha" },
        { en = "Bulletproof", es = "A Prueba de Balas" },
        { en = "the Cheat", es = "el Tramposo", es_f = "la Tramposa" },
        { en = "Thick-Skinned", es = "Pellejo Duro" },
        { en = "the Stubborn", es = "el Terco", es_f = "la Terca" },
        { en = "Bloodied", es = "Ensangrentado", es_f = "Ensangrentada" },
        { en = "the Limper", es = "el Cojo", es_f = "la Coja" },
        { en = "One-Eye", es = "Tuerto", es_f = "Tuerta" },
        { en = "the Scarred", es = "el Marcado", es_f = "la Marcada" },
        { en = "Ironhide", es = "Piel de Hierro" },
        { en = "the Unbroken", es = "el Inquebrantable", es_f = "la Inquebrantable" },
        { en = "Stitches", es = "Puntos" },
        { en = "Born Lucky", es = "Nacido con Estrella", es_f = "Nacida con Estrella" },
        { en = "Last One Standing", es = "el Último en Pie", es_f = "la Última en Pie" },
        { en = "the Bleeder", es = "el Sangrante", es_f = "la Sangrante" },
        { en = "the Tough", es = "el Duro", es_f = "la Dura" },
        { en = "the Dodger", es = "el Esquivador", es_f = "la Esquivadora" },
        { en = "Jinx", es = "Gafe" },
        { en = "the Weed", es = "la Mala Hierba" },
        { en = "the Alley Cat", es = "el Gato Callejero", es_f = "la Gata Callejera" },
        { en = "Hard to Kill", es = "Difícil de Matar" },
        { en = "the Stray", es = "el Callejero", es_f = "la Callejera" },
        { en = "Twice Shot", es = "Dos Veces Baleado", es_f = "Dos Veces Baleada" },
        { en = "the Grinning", es = "el Sonriente", es_f = "la Sonriente" },
        { en = "Broken Nose", es = "Nariz Rota" },
        { en = "the Mad Dog", es = "el Perro Rabioso", es_f = "la Perra Rabiosa" },
        { en = "the Wounded", es = "el Herido", es_f = "la Herida" },
        { en = "the Slippery", es = "el Escurridizo", es_f = "la Escurridiza" },
        { en = "the Bitter", es = "el Amargado", es_f = "la Amargada" },
        { en = "the Vengeful", es = "el Vengativo", es_f = "la Vengativa" },
        { en = "Gutshot", es = "Tiro en la Panza" },
        { en = "the Relentless", es = "el Implacable", es_f = "la Implacable" },
        { en = "Nothing to Lose", es = "Nada que Perder" },
        { en = "Dead Man Walking", es = "Muerto Andante", es_f = "Muerta Andante" },
        { en = "the Cursed", es = "el Maldito", es_f = "la Maldita" },
        { en = "the Grim", es = "el Sombrío", es_f = "la Sombría" },
        { en = "Scorched", es = "Chamuscado", es_f = "Chamuscada" },
        { en = "Shrapnel", es = "Metralla" },
        { en = "the Sore Loser", es = "el Mal Perdedor", es_f = "la Mala Perdedora" },
    },
}
titles.fled = {
    { en = "the Coward", es = "el Cobarde", es_f = "la Cobarde" },
    { en = "the Hare", es = "la Liebre" },
    { en = "Quickfeet", es = "Pies Ligeros" },
    { en = "the Deserter", es = "el Desertor", es_f = "la Desertora" },
    { en = "the Ghost", es = "el Fantasma" },
    { en = "Runaway", es = "el Prófugo", es_f = "la Prófuga" },
    { en = "the Chicken", es = "la Gallina" },
    { en = "Yellow", es = "Amarillo", es_f = "Amarilla" },
    { en = "the Sprinter", es = "el Velocista", es_f = "la Velocista" },
    { en = "Cut-and-Run", es = "Sal Corriendo" },
    { en = "the Fox", es = "el Zorro", es_f = "la Zorra" },
    { en = "Bolt", es = "Rayo" },
    { en = "Skedaddle", es = "Despavorido", es_f = "Despavorida" },
    { en = "the Vanisher", es = "el Que Desaparece", es_f = "la Que Desaparece" },
    { en = "No-Show", es = "el Ausente", es_f = "la Ausente" },
    { en = "the Quitter", es = "el Rajado", es_f = "la Rajada" },
    { en = "Turncoat", es = "Chaquetero", es_f = "Chaquetera" },
    { en = "the Deer", es = "el Venado" },
    { en = "Scaredy", es = "el Miedoso", es_f = "la Miedosa" },
    { en = "the Weasel", es = "la Comadreja" },
    { en = "Hasty", es = "el Apresurado", es_f = "la Apresurada" },
    { en = "the Sneak", es = "el Sigiloso", es_f = "la Sigilosa" },
    { en = "Back Door", es = "Puerta Trasera" },
    { en = "the Craven", es = "el Pusilánime", es_f = "la Pusilánime" },
    { en = "the Escapist", es = "el Escapista", es_f = "la Escapista" },
    { en = "the Gazelle", es = "la Gacela" },
    { en = "Dust Trail", es = "Estela de Polvo" },
    { en = "Spooked", es = "Asustado", es_f = "Asustada" },
    { en = "Panic", es = "Pánico" },
    { en = "Tail Between Legs", es = "Rabo entre las Piernas" },
    { en = "Houdini", es = "Houdini" },
    { en = "the Lamb", es = "el Cordero", es_f = "la Cordera" },
    { en = "the Roadrunner", es = "el Correcaminos" },
    { en = "the Hider", es = "el Escondido", es_f = "la Escondida" },
    { en = "Cold Feet", es = "Pies Fríos" },
    { en = "Whitefeather", es = "Pluma Blanca" },
    { en = "Smokescreen", es = "Cortina de Humo" },
    { en = "the Evader", es = "el Evasor", es_f = "la Evasora" },
    { en = "Last Out", es = "el Último en Salir", es_f = "la Última en Salir" },
    { en = "the Pigeon", es = "la Paloma" },
    { en = "the Mouse", es = "el Ratón", es_f = "la Ratona" },
    { en = "Yellowbelly", es = "Panza Amarilla" },
    { en = "the Quiet Exit", es = "Salida Discreta" },
}
titles.debug = titles.escaped

titles.promoted = {
    { en = "the Heir", es = "el Heredero", es_f = "la Heredera" },
    { en = "the Usurper", es = "el Usurpador", es_f = "la Usurpadora" },
    { en = "Iron Fist", es = "Puño de Hierro" },
    { en = "the Climber", es = "el Trepa", es_f = "la Trepa" },
    { en = "the New Blood", es = "Sangre Nueva" },
    { en = "the Enforcer", es = "el Ejecutor", es_f = "la Ejecutora" },
    { en = "the Rising", es = "el Ascendente", es_f = "la Ascendente" },
    { en = "the Ambitious", es = "el Ambicioso", es_f = "la Ambiciosa" },
    { en = "the Successor", es = "el Sucesor", es_f = "la Sucesora" },
    { en = "the Right Hand", es = "la Mano Derecha" },
    { en = "the Upstart", es = "el Advenedizo", es_f = "la Advenediza" },
    { en = "the Chosen", es = "el Elegido", es_f = "la Elegida" },
    { en = "the Captain", es = "el Capitán", es_f = "la Capitana" },
    { en = "the Lieutenant", es = "el Teniente", es_f = "la Teniente" },
    { en = "the Shot-Caller", es = "el Que Manda", es_f = "la Que Manda" },
    { en = "the Favorite", es = "el Favorito", es_f = "la Favorita" },
    { en = "the Crowned", es = "el Coronado", es_f = "la Coronada" },
    { en = "the Hardliner", es = "el Intransigente", es_f = "la Intransigente" },
    { en = "the Proven", es = "el Probado", es_f = "la Probada" },
    { en = "Kingmaker", es = "Hacedor de Reyes", es_f = "Hacedora de Reyes" },
    { en = "the Overseer", es = "el Capataz", es_f = "la Capataz" },
    { en = "the Taskmaster", es = "el Mandón", es_f = "la Mandona" },
    { en = "Brass Knuckles", es = "Nudillos de Latón" },
    { en = "the Closer", es = "el Rematador", es_f = "la Rematadora" },
    { en = "the Cleaner", es = "el Limpiador", es_f = "la Limpiadora" },
    { en = "the Warlord", es = "el Señor de la Guerra", es_f = "la Señora de la Guerra" },
    { en = "the Commander", es = "el Comandante", es_f = "la Comandante" },
    { en = "the Vanguard", es = "la Vanguardia" },
    { en = "Big Shot", es = "Pez Gordo" },
    { en = "the Strongarm", es = "el Matón", es_f = "la Matona" },
    { en = "Bossman", es = "Jefazo", es_f = "Jefaza" },
    { en = "the Chief", es = "el Jefe", es_f = "la Jefa" },
    { en = "the Ascendant", es = "el Ascendido", es_f = "la Ascendida" },
    { en = "the Aspirant", es = "el Aspirante", es_f = "la Aspirante" },
    { en = "the Dauphin", es = "el Delfín", es_f = "la Delfina" },
    { en = "Iron Crown", es = "Corona de Hierro" },
    { en = "Gold Tooth", es = "Diente de Oro" },
    { en = "the Regent", es = "el Regente", es_f = "la Regente" },
    { en = "the Whip", es = "el Látigo" },
    { en = "the Hammer", es = "el Martillo" },
    { en = "the Blade", es = "el Filo" },
    { en = "the Sergeant", es = "el Sargento", es_f = "la Sargento" },
    { en = "the Underboss", es = "el Subjefe", es_f = "la Subjefa" },
    { en = "the Marshal", es = "el Mariscal", es_f = "la Mariscal" },
}

titles.returned = {
    { en = "the Rebuilt", es = "el Reconstruido", es_f = "la Reconstruida" },
    { en = "Scrap", es = "Chatarra" },
    { en = "the Revenant", es = "el Aparecido", es_f = "la Aparecida" },
    { en = "Chrome Ghost", es = "Fantasma de Cromo" },
    { en = "Second Life", es = "Segunda Vida" },
    { en = "the Undying", es = "el Que No Muere", es_f = "la Que No Muere" },
    { en = "Rebooted", es = "Reiniciado", es_f = "Reiniciada" },
    { en = "the Reborn", es = "el Renacido", es_f = "la Renacida" },
    { en = "Chrome Skull", es = "Calavera de Cromo" },
    { en = "the Resurrected", es = "el Resucitado", es_f = "la Resucitada" },
    { en = "Second Wind", es = "Segundo Aliento" },
    { en = "the Upgraded", es = "el Mejorado", es_f = "la Mejorada" },
    { en = "Version Two", es = "Versión Dos" },
    { en = "Mk II", es = "Mk II" },
    { en = "Reforged", es = "Reforjado", es_f = "Reforjada" },
    { en = "Salvaged", es = "el Recuperado", es_f = "la Recuperada" },
    { en = "the Rewired", es = "el Recableado", es_f = "la Recableada" },
    { en = "Ripperdoc's Pride", es = "Orgullo del Matasanos" },
    { en = "Steel Heart", es = "Corazón de Acero" },
    { en = "Iron Lung", es = "Pulmón de Hierro" },
    { en = "the Hollow Man", es = "el Hombre Hueco", es_f = "la Mujer Hueca" },
    { en = "Chrome Jaw", es = "Mandíbula de Cromo" },
    { en = "the Machine", es = "la Máquina" },
    { en = "Cold Reboot", es = "Reinicio en Frío" },
    { en = "Spare Parts", es = "Piezas de Repuesto" },
    { en = "Overclocked", es = "Sobrecargado", es_f = "Sobrecargada" },
    { en = "Secondhand", es = "De Segunda Mano" },
    { en = "Corpse Chrome", es = "Cadáver Cromado" },
    { en = "Borrowed Time", es = "Tiempo Prestado" },
    { en = "Lazarus", es = "Lázaro" },
    { en = "the Phoenix", es = "el Fénix" },
    { en = "Neon Ghost", es = "Fantasma de Neón" },
    { en = "Steel Spine", es = "Columna de Acero" },
    { en = "the Returned", es = "el Retornado", es_f = "la Retornada" },
    { en = "Static Ghost", es = "Fantasma Estático" },
    { en = "Boosted", es = "Potenciado", es_f = "Potenciada" },
    { en = "Black Chrome", es = "Cromo Negro" },
    { en = "Metal Mouth", es = "Boca de Metal" },
    { en = "the Stitched Up", es = "el Zurcido", es_f = "la Zurcida" },
    { en = "Servo Soul", es = "Alma de Servo" },
    { en = "Bad Firmware", es = "Firmware Defectuoso" },
    { en = "Dead Circuits", es = "Circuitos Muertos" },
    { en = "Spare Heart", es = "Corazón de Repuesto" },
}

local function pick(list)
    return list[math.random(#list)]
end

local function isFemale(gender)
    return gender == "Female"
end

function Names.generate(gang, gender, origin, taken)
    local pool = pools[gang] or pools.Maelstrom
    local name
    for _ = 1, 30 do
        if pool.style == "handle" then
            name = pick(pool.handles)
        else
            local first = isFemale(gender) and pick(pool.female) or pick(pool.male)
            name = first .. " " .. pick(pool.last)
        end
        if not (taken and taken[name]) then break end
    end

    if taken and taken[name] then
        local base, numerals = name, { "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
        for _, numeral in ipairs(numerals) do
            name = base .. " " .. numeral
            if not taken[name] then break end
        end
    end

    local title = pick(titles[origin] or titles.escaped)
    local titleEs = title.es
    if isFemale(gender) and title.es_f then titleEs = title.es_f end

    return name, title.en, titleEs
end

function Names.returnedTitle(gender)
    local title = pick(titles.returned)
    local es = (isFemale(gender) and title.es_f) or title.es
    return title.en, es
end

function Names.display(nemesis, lang)
    local title = (lang == "es") and nemesis.titleEs or nemesis.titleEn
    if not title or title == "" then return nemesis.name or "?" end
    return string.format('%s "%s"', nemesis.name or "?", title)
end

function Names.gangLabel(gang)
    return Names.gangLabels[gang] or gang or "?"
end

return Names
