let reportlist_translations = {
    "en": {
        id: "Id",
        stat_group: "Statistical group",
        start_date: "From",
        end_date: "To",
        created: "Created",
    },
    "fi": {
        id: "Id",
        stat_group: "Tilastoryhmä",
        start_date: "Alkaen",
        end_date: "Päättyen",
        created: "Luotu",
    },
    "sv": {
        id: "Id",
        stat_group: "Statistisk grupp",
        start_date: "Från",
        end_date: "Till",
        created: "Skapad",
    }
}

function lt(key, ...args) {
  // Detect language, default to 'en'
  const lang = (language || "en").substring(0,2);
  const dict = reportlist_translations[lang] ||  reportlist_translations["en"];
  const val = dict[key];
  return typeof val === "function" ? val(...args) : val;
}

const okmreportlistfields = [
    { label: lt("id"), key: "0", sortable: true },
    { label: lt("stat_group"), key: "1" , sortable: true},
    { label: lt("start_date"), key: "2" , sortable: true},
    { label: lt("end_date"), key: "3" , sortable: true},
    { label: lt("created"), key: "4" , sortable: true, filter: false}
]