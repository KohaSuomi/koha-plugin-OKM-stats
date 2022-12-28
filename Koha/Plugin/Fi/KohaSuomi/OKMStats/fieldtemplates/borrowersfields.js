const borrower_agegroup_fields = [
    { label: "Kirjastotunnus", key: "0", sortable: true },
    { label: "0-14-v.", key: "1" , sortable: true},
    { label: "15-19-v.", key: "2" , sortable: true},
    { label: "20-29-v.", key: "3", sortable: true },
    { label: "30-39-v.", key: "4", sortable: true },
    { label: "40-49-v.", key: "5", sortable: true },
    { label: "50-59-v.", key: "6", sortable: true },
    { label: "60-69-v.", key: "7", sortable: true },
    { label: "70-79-v.", key: "8", sortable: true },
    { label: "80-89-v.", key: "9", sortable: true },
    { label: "90-99-v.", key: "10", sortable: true },
    { label: "100-", key: "11", sortable: true }
]

const borrower_issuesbyzip_fields = [
    { label: "Kirjastotunnus", key: "0", sortable: true },
    { label: "Kaupunki", key: "1" , sortable: true},
    { label: "Postinumero", key: "2" , sortable: true},
    { label: "Asiakkaiden lkm", key: "3", sortable: true },
    { label: "Ensilainojen lkm", key: "4", sortable: true }
]

const borrower_issuesbypatronzip_fields = [
    { label: "Postinumero", key: "0", sortable: true },
    { label: "Lainat", key: "1", sortable: true },
    { label: "Uusinnat", key: "2" , sortable: true},
    { label: "Lainat + uusinnat", key: "3" , sortable: true}
]