# JCIF
Journal Commercial Impact Factor

## Motivation
This measure is analogous to the commonly used Journal Impact Factor (JIF), which is also calculated here. 
A journal’s impact factor is a popular measure of its quality, calculated for year t as the number of times articles from years t-1 and t-2 were cited during year t, divided by the number of articles published during years t-1 and t-2. 
Just like JIF is a journal-level measure of quality, it is possible to build a journal-level measure of appliedness or commercial relevance by replacing paper-to-paper citationss by patent-to-paper citations.
Michael Bikard and I introduced JCIF in our paper "From Academia to Industry: Hubs as Bridges between University Science and Corporate Technologies", available at https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3006859. We would appreciate you citing the paper if you use the measure.

## Data sources
Patent data are from PatentsView (http://www.patentsview.org/download/). We use the application year of the patent and the indicator for whether the patent belongs to a firm, as patents belonging to universities, government agencies, and lone inventors are not included in the numerator of JCIF.
Patent-to-paper citations are from Marx & Fuegi (2019), described at https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3331686. These are front-page USPTO citations from 1947-2018. Citations prior to 1976 are captured via OCR and are less reliable, so we would discourage relying on JCIF computed prior to 1976.
Paper data is from the Microsoft Academic Graph (MAG), described at https://www.microsoft.com/en-us/research/project/microsoft-academic-graph/. MAG is distributed under the ODC-BY license, under which these data are also distributed as they include journal names from MAG.
Both the patent-to-paper citations themselves as well as MAG can be downloaded from ICPSR: https://www.openicpsr.org/openicpsr/project/108362/version/V12/view/. The latest version is always available at http://linksplit.io/reliance_on_science. 

## Output file
The output files jif.tsv and jcif.tsv contains the calculations for each journal in each year when it had publications. Fields are:
* *year*
* *journalname* - this is the unaltered journal name from the Microsoft Academic Graph
* *journalid* - this is the unique journal ID from the Microsoft Academic Graph. Note that a very small number of journal IDs have the same journal name.
* *jcif* - calculated as described above. 

## Replication
If you prefer, you can build the .tsv files yourself using the mag_jif_jcif.do script. It is a Stata file tested on version 14.2 and with the following requirements:
1. Download four patent-related files from PatentsView: application.tsv, patent.tsv, assignee.tsv, and patent_assignee.tsv (yes, those final two files are distinct).
2. Set the global variable $pvtsv to the directory where those are located.
3. Download pcs.tsv (http://linksplit.io/reliance_on_science) and set the global variable $pcs to the directory where it is located. 
4. Download paperyear.tsv, paperjournalid.tsv, and journalidname.tsv from ICPSR (http://linksplit.io/reliance_on_science). Set the global variable $magtsv to the directory where they are located.
5. Set the global variables $mag and $pv to wherever you want to store the .dta versions of the MAG and PatentsView files you downloaded. It can be the current working directory, i.e., "./"
6. Set the global variable $output to whereever you want intermediate and final files to be stored.



