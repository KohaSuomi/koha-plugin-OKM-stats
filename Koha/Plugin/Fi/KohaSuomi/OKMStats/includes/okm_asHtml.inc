<table>
    <thead>
        <tr>
            <th>Library</th>
            <!--Collection by homebranch-->
            <th>Collection by homebranch total</th>
            <th>Collection by homebranch books total</th>
            <th>Collection by homebranch books finnish</th>
            <th>Collection by homebranch books swedish</th>
            <th>Collection by homebranch books sami</th>
            <th>Collection by homebranch books other language</th>
            <th>Collection by homebranch books fiction adult</th>
            <th>Collection by homebranch books fiction juvenile</th>
            <th>Collection by homebranch books fact adult</th>
            <th>Collection by homebranch books fact juvenile</th>
            <th>Collection by homebranch sheet music score</th>
            <th>Collection by homebranch musical recordings</th>
            <th>Collection by homebranch other regordings</th>
            <th>Collection by homebranch videos</th>
            <th>Collection by homebranch celia</th>
            <th>Collection by homebranch other</th>
            <!--Collection by holdingbranch-->
            <th>Collection by holdingbranch total</th>
            <th>Collection by holdingbranch books total</th>
            <th>Collection by holdingbranch books finnish</th>
            <th>Collection by holdingbranch books swedish</th>
            <th>Collection by holdingbranch books sami</th>
            <th>Collection by holdingbranch books other language</th>
            <th>Collection by holdingbranch books fiction adult</th>
            <th>Collection by holdingbranch books fiction juvenile</th>
            <th>Collection by holdingbranch books fact adult</th>
            <th>Collection by holdingbranch books fact juvenile</th>
            <th>Collection by holdingbranch sheet music score</th>
            <th>Collection by holdingbranch musical recordings</th>
            <th>Collection by holdingbranch other regordings</th>
            <th>Collection by holdingbranch videos</th>
            <th>Collection by holdingbranch celia</th>
            <th>Collection by holdingbranch other</th>
            <!--Issues-->
            <th>Issues total</th>
            <th>Issues books total</th>
            <th>Issues books finnish</th>
            <th>Issues books swedish</th>
            <th>Issues books sami</th>
            <th>Issues books other language</th>
            <th>Issues books fiction adult</th>
            <th>Issues books fiction juvenile</th>
            <th>Issues books fact adult</th>
            <th>Issues books fact juvenile</th>
            <th>Issues sheet music score</th>
            <th>Issues musical recordings</th>
            <th>Issues other regordings</th>
            <th>Issues videos</th>
            <th>Issues celia</th>
            <th>Issues other</th>
            <!--Deleted-->
            <th>Deleted total</th>
            <th>Deleted books total</th>
            <th>Deleted books finnish</th>
            <th>Deleted books swedish</th>
            <th>Deleted books sami</th>
            <th>Deleted books other language</th>
            <th>Deleted books fiction adult</th>
            <th>Deleted books fiction juvenile</th>
            <th>Deleted books fact adult</th>
            <th>Deleted books fact juvenile</th>
            <th>Deleted sheet music score</th>
            <th>Deleted musical recordings</th>
            <th>Deleted other regordings</th>
            <th>Deleted videos</th>
            <th>Deleted celia</th>
            <th>Deleted other</th>
            <!--Acquisitions-->
            <th>Acquisitions total</th>
            <th>Acquisitions books total</th>
            <th>Acquisitions books finnish</th>
            <th>Acquisitions books swedish</th>
            <th>Acquisitions books sami</th>
            <th>Acquisitions books other language</th>
            <th>Acquisitions books fiction adult</th>
            <th>Acquisitions books fiction juvenile</th>
            <th>Acquisitions books fact adult</th>
            <th>Acquisitions books fact juvenile</th>
            <th>Acquisitions sheet music score</th>
            <th>Acquisitions musical recordings</th>
            <th>Acquisitions other regordings</th>
            <th>Acquisitions videos</th>
            <th>Acquisitions celia</th>
            <th>Acquisitions other</th>
            <!--Active borrowers-->
            <th>Active borrowers</th>
        </tr>
    </thead>
    [% FOREACH okm_stat IN okm_stats %]
    <tr>
        <td>[% okm_stat.library %]</td>
        <!--Collection by homebranch-->
        <td>[% okm_stat.collection_by_homebranch.total %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_total %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_finnish %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_swedish %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_sami %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_other_lang %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_fiction_adult %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_fiction_juvenile %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_fact_adult %]</td>
        <td>[% okm_stat.collection_by_homebranch.books_fact_juvenile %]</td>
        <td>[% okm_stat.collection_by_homebranch.sheet_music_score %]</td>
        <td>[% okm_stat.collection_by_homebranch.musical_regordins %]</td>
        <td>[% okm_stat.collection_by_homebranch.other_regordings %]</td>
        <td>[% okm_stat.collection_by_homebranch.videos %]</td>
        <td>[% okm_stat.collection_by_homebranch.celia %]</td>
        <td>[% okm_stat.collection_by_homebranch.other %]</td>
        <!--Collection by holdingbranch-->
        <td>[% okm_stat.collection_by_holdingbranch.total %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_total %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_finnish %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_swedish %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_sami %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_other_lang %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_fiction_adult %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_fiction_juvenile %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_fact_adult %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.books_fact_juvenile %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.sheet_music_score %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.musical_regordins %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.other_regordings %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.videos %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.celia %]</td>
        <td>[% okm_stat.collection_by_holdingbranch.other %]</td>
        <!--Issues-->
        <td>[% okm_stat.issues.total %]</td>
        <td>[% okm_stat.issues.books_total %]</td>
        <td>[% okm_stat.issues.books_finnish %]</td>
        <td>[% okm_stat.issues.books_swedish %]</td>
        <td>[% okm_stat.issues.books_sami %]</td>
        <td>[% okm_stat.issues.books_other_lang %]</td>
        <td>[% okm_stat.issues.books_fiction_adult %]</td>
        <td>[% okm_stat.issues.books_fiction_juvenile %]</td>
        <td>[% okm_stat.issues.books_fact_adult %]</td>
        <td>[% okm_stat.issues.books_fact_juvenile %]</td>
        <td>[% okm_stat.issues.sheet_music_score %]</td>
        <td>[% okm_stat.issues.musical_regordins %]</td>
        <td>[% okm_stat.issues.other_regordings %]</td>
        <td>[% okm_stat.issues.videos %]</td>
        <td>[% okm_stat.issues.celia %]</td>
        <td>[% okm_stat.issues.other %]</td>
        <!--Deleted-->
        <td>[% okm_stat.deleted.total %]</td>
        <td>[% okm_stat.deleted.books_total %]</td>
        <td>[% okm_stat.deleted.books_finnish %]</td>
        <td>[% okm_stat.deleted.books_swedish %]</td>
        <td>[% okm_stat.deleted.books_sami %]</td>
        <td>[% okm_stat.deleted.books_other_lang %]</td>
        <td>[% okm_stat.deleted.books_fiction_adult %]</td>
        <td>[% okm_stat.deleted.books_fiction_juvenile %]</td>
        <td>[% okm_stat.deleted.books_fact_adult %]</td>
        <td>[% okm_stat.deleted.books_fact_juvenile %]</td>
        <td>[% okm_stat.deleted.sheet_music_score %]</td>
        <td>[% okm_stat.deleted.musical_regordins %]</td>
        <td>[% okm_stat.deleted.other_regordings %]</td>
        <td>[% okm_stat.deleted.videos %]</td>
        <td>[% okm_stat.deleted.celia %]</td>
        <td>[% okm_stat.deleted.other %]</td>
        <!--Acquisitions-->
        <td>[% okm_stat.acquisitions.total %]</td>
        <td>[% okm_stat.acquisitions.books_total %]</td>
        <td>[% okm_stat.acquisitions.books_finnish %]</td>
        <td>[% okm_stat.acquisitions.books_swedish %]</td>
        <td>[% okm_stat.acquisitions.books_sami %]</td>
        <td>[% okm_stat.acquisitions.books_other_lang %]</td>
        <td>[% okm_stat.acquisitions.books_fiction_adult %]</td>
        <td>[% okm_stat.acquisitions.books_fiction_juvenile %]</td>
        <td>[% okm_stat.acquisitions.books_fact_adult %]</td>
        <td>[% okm_stat.acquisitions.books_fact_juvenile %]</td>
        <td>[% okm_stat.acquisitions.sheet_music_score %]</td>
        <td>[% okm_stat.acquisitions.musical_regordins %]</td>
        <td>[% okm_stat.acquisitions.other_regordings %]</td>
        <td>[% okm_stat.acquisitions.videos %]</td>
        <td>[% okm_stat.acquisitions.celia %]</td>
        <td>[% okm_stat.acquisitions.other %]</td>
        <!--Active borrowers-->
        <td>[% okm_stat.active_borrowers %]</td>
    </tr>

    [% END %]
</table>