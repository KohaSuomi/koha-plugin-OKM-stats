let okmfields = [
    {
        label: "Kirjastotunnus",
        key: "library",
        sortable: true,
        stickyColumn: true,
        isRowHeader: true,
        variant: "primary",
      },
        
        
        { label: "Kokoelmat (sijainti): Yhteensä", key: "collection_by_holdingbranch.total", sortable: true, variant: 'info'},
        { label: "Kokoelmat (sijainti): Kirjat Yhteensä", key: "collection_by_holdingbranch.books_total" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Suomenkieliset ", key: "collection_by_holdingbranch.books_finnish" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Ruotsinkieliset ", key: "collection_by_holdingbranch.books_swedish" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Saamenkieliset", key: "collection_by_holdingbranch.books_sami" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Muunkieliset", key: "collection_by_holdingbranch.books_other_lang" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Kaunokirjat, aikuiset", key: "collection_by_holdingbranch.books_fiction_adult" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Kaunokirjat, lapset", key: "collection_by_holdingbranch.books_fiction_juvenile" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Tietokirjat, aikuiset", key: "collection_by_holdingbranch.books_fact_adult" , sortable: true, },
        { label: "Kokoelmat (sijainti): Kirjat Tietokirjat, lapset", key: "collection_by_holdingbranch.books_fact_juvenile" , sortable: true, },
        { label: "Kokoelmat (sijainti): Nuotit ja partituurit", key: "collection_by_holdingbranch.sheet_music_score" , sortable: true, },
        { label: "Kokoelmat (sijainti): Musiikkiäänitteet", key: "collection_by_holdingbranch.musical_regordins" , sortable: true, },
        { label: "Kokoelmat (sijainti): Muut äänitteet", key: "collection_by_holdingbranch.other_regordings" , sortable: true, },
        { label: "Kokoelmat (sijainti): Videotallenteet", key: "collection_by_holdingbranch.videos" , sortable: true, },
        { label: "Kokoelmat (sijainti): Celia", key: "collection_by_holdingbranch.celia" , sortable: true, },
        { label: "Kokoelmat (sijainti): Muut aineistot", key: "collection_by_holdingbranch.other" , sortable: true, },
        
        { label: "Kokoelmat (koti): Yhteensä", key: "collection_by_homebranch.total", sortable: true, variant: 'info'},
        { label: "Kokoelmat (koti): Kirjat Yhteensä", key: "collection_by_homebranch.books_total" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Suomenkieliset ", key: "collection_by_homebranch.books_finnish" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Ruotsinkieliset ", key: "collection_by_homebranch.books_swedish" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Saamenkieliset", key: "collection_by_homebranch.books_sami" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Muunkieliset", key: "collection_by_homebranch.books_other_lang" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Kaunokirjat, aikuiset", key: "collection_by_homebranch.books_fiction_adult" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Kaunokirjat, lapset", key: "collection_by_homebranch.books_fiction_juvenile" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Tietokirjat, aikuiset", key: "collection_by_homebranch.books_fact_adult" , sortable: true, },
        { label: "Kokoelmat (koti): Kirjat Tietokirjat, lapset", key: "collection_by_homebranch.books_fact_juvenile" , sortable: true, },
        { label: "Kokoelmat (koti): Nuotit ja partituurit", key: "collection_by_homebranch.sheet_music_score" , sortable: true, },
        { label: "Kokoelmat (koti): Musiikkiäänitteet", key: "collection_by_homebranch.musical_regordins" , sortable: true, },
        { label: "Kokoelmat (koti): Muut äänitteet", key: "collection_by_homebranch.other_regordings" , sortable: true, },
        { label: "Kokoelmat (koti): Videotallenteet", key: "collection_by_homebranch.videos" , sortable: true, },
        { label: "Kokoelmat (koti): Celia", key: "collection_by_homebranch.celia" , sortable: true, },
        { label: "Kokoelmat (koti): Muut aineistot", key: "collection_by_homebranch.other" , sortable: true, },
        
        { label: "Hankinnat: Yhteensä", key: "acquisitions.total" , sortable: true, variant: 'info'},
        { label: "Hankinnat: Kirjat Yhteensä", key: "acquisitions.books_total" , sortable: true,},
        { label: "Hankinnat: Kirjat Suomenkieliset", key: "acquisitions.books_finnish" , sortable: true,},
        { label: "Hankinnat: Kirjat Ruotsinkieliset", key: "acquisitions.books_swedish" , sortable: true,},
        { label: "Hankinnat: Kirjat Saamenkieliset", key: "acquisitions.books_sami" , sortable: true,},
        { label: "Hankinnat: Kirjat Muunkieliset", key: "acquisitions.books_other_lang" , sortable: true,},
        { label: "Hankinnat: Kirjat Kaunokirjat, aikuiset", key: "acquisitions.books_fiction_adult" , sortable: true,},
        { label: "Hankinnat: Kirjat Kaunokirjat, lapset", key: "acquisitions.books_fiction_juvenile" , sortable: true,},
        { label: "Hankinnat: Kirjat Tietokirjat, aikuiset", key: "acquisitions.books_fact_adult" , sortable: true,},
        { label: "Hankinnat: Kirjat Tietokirjat, lapset", key: "acquisitions.books_fact_juvenile" , sortable: true,},
        { label: "Hankinnat: Nuotit ja partituurit", key: "acquisitions.sheet_music_score" , sortable: true,},
        { label: "Hankinnat: Musiikkiäänitteet", key: "acquisitions.musical_regordins" , sortable: true,},
        { label: "Hankinnat: Celia", key: "acquisitions.celia" , sortable: true,},
        { label: "Hankinnat: Muut äänitteet", key: "acquisitions.other_regordings" , sortable: true,},
        { label: "Hankinnat: Videotallenteet", key: "acquisitions.videos" , sortable: true,},
        { label: "Hankinnat: Muut aineistot", key: "acquisitions.other" , sortable: true,},
        
        { label: "Lainaus: Yhteensä", key: "issues.total" , sortable: true, variant: 'info'},
        { label: "Lainaus: Kirjat Yhteensä", key: "issues.books_total" , sortable: true,},
        { label: "Lainaus: Kirjat Suomenkieliset", key: "issues.books_finnish" , sortable: true,},
        { label: "Lainaus: Kirjat Ruotsinkieliset", key: "issues.books_swedish" , sortable: true,},
        { label: "Lainaus: Kirjat Saamenkieliset", key: "issues.books_sami" , sortable: true,},
        { label: "Lainaus: Kirjat Muunkieliset", key: "issues.books_other_lang" , sortable: true,},
        { label: "Lainaus: Kirjat Kaunokirjat, aikuiset", key: "issues.books_fiction_adult" , sortable: true,},
        { label: "Lainaus: Kirjat Kaunokirjat, lapset", key: "issues.books_fiction_juvenile" , sortable: true,},
        { label: "Lainaus: Kirjat Tietokirjat, aikuiset", key: "issues.books_fact_adult" , sortable: true,},
        { label: "Lainaus: Kirjat Tietokirjat, lapset", key: "issues.books_fact_juvenile" , sortable: true,},
        { label: "Lainaus: Nuotit ja partituurit", key: "issues.sheet_music_score" , sortable: true,},
        { label: "Lainaus: Musiikkiäänitteet", key: "issues.musical_regordins" , sortable: true,},
        { label: "Lainaus: Celia", key: "issues.celia" , sortable: true,},
        { label: "Lainaus: Muut äänitteet", key: "issues.other_regordings" , sortable: true,},
        { label: "Lainaus: Videotallenteet", key: "issues.videos" , sortable: true,},
        { label: "Lainaus: Muut aineistot", key: "issues.other" , sortable: true,},
        
        { label: "Sanomalehdet", key: "serials.newspaper" , sortable: true, variant: 'info'},
        { label: "Aikakauslehdet", key: "serials.serials" , sortable: true,},
        
        { label: "Poistot", key: "deleted.total" , sortable: true, variant: 'info'},
        
        { label: "Aktiiviset asiakkaat", key: "active_borrowers" , sortable: true, variant: 'info'},
        
        { label: "Hankinta(kulut) yhteensä", key: "acquisitions.expenditure_acquisitions" , sortable: true, variant: 'info'},
        { label: "Kirjojen hankinta(kulut)", key: "acquisitions.expenditure_acquisitions_books" , sortable: true, variant: 'info'},
        
        
        
        
        
        
  ];
  

  
  
  //uusokmtest.json
  
  
  //näitä ei käytetä

//   "acquisitions": {
//     "expenditure_acquisitions_books": 2004.81,

//     "books_finnish": 0,

//     "itemtypes": {
//         "": 6,
//         "KONSOLIP": 9,
//         "CD": 11,
//         "NUOTTI": 2,
//         "DVD": 12,
//         "KIRJA": 116
//     },
//     "expenditure_acquisitions": 3509.23,

// },

//   "collection_by_holdingbranch": {
//     "": 2339,
//     "itemtypes": {
//         "NUOTTI": 156,
//         "DVD": 45,
//         "PUHECD": 238,
//         "KARTTA": 3,
//         "DIA": 2,
//         "ESINE": 1,
//         "KONSOLIP": 19,
//         "ATLAS": 4,
//         "KIRJA": 22528,
//         "CD": 192,
//         "MONIVIES": 84
//     },
   // "books_finnish": 0,
//},

// "issues": {
  
// },

// "serials": {
//   "serials": 0,
//   "total": 0,
//   "journals": 0,
//   "newspaper": 0
// },


//  	 	 	
