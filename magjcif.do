global magtsv "../pcs/magdata-papersonly"
global pcs "../pcs/"
global pvtsv "../../patents/patentsview/tsv/"
global pv "./"
global mag "./"

import delimited using $pvtsv/patent.tsv, clear varnames(1)
keep number
rename number patnum
duplicates drop
save patnum, replace
import delimited using $pvtsv/application.tsv, clear varnames(1)
keep patent_id date
rename patent_id patnum
gen appyear = regexs(1) if regexm(date, "^([0-9][0-9][0-9][0-9])")
drop date
merge 1:1 patnum using patnum, keep(3) nogen
save patnumappyear, replace
import delimited using $pvtsv/assignee.tsv, clear varnames(1)
gen firmassignee = 0
replace firmassignee = 1 if type==2
replace firmassignee = 1 if type==3
keep id firmassignee
rename id assigneeid
save assigneeisfirm, replace
* type: irms = 1,3
import delimited using $pvtsv/patent_assignee.tsv, clear varnames(1)
rename assignee_id assigneeid
rename patent_id patnum
save patent_assigneeid, replace
use patent_assigneeid, clear
merge m:1 assigneeid using assigneeisfirm, keep(3) nogen
bys patnum: egen pctfirmassignees = mean(firmassignee)
keep patnum pctfirmassignees
duplicates drop
save pctpatfirmassigned, replace
use patnumappyear, clear
merge 1:1 patnum using pctpatfirmassigned, keep(3) nogen
gen patfirm = pctfirmassignees>0
drop pctfirmassignees
save patnumappyearfirmpat, replace

import delimited using $magtsv/paperyear.tsv, clear varnames(1)
rename paperid magid
rename paperyear year
save $mag/magyear, replace
import delimited using $magtsv/paperjournalid.tsv, clear varnames(1)
rename paperid magid
save $mag/magjournalid, replace
import delimited using $magtsv/journalidname.tsv, clear varnames(1)
drop journalname
rename v3 journalname
save $mag/journalidname, replace
import delimited using $pcs/pcs.tsv, clear varnames(1)
save $mag/pcs, replace

use $mag/magyear, clear
merge 1:1 magid using $mag/magjournalid, keep(3) nogen
gen int npapers = 1
drop magid
fcollapse (sum) npapers, by(year journalid)
sort journalid year
gen jafdenominator = .
replace jafdenominator = 0 if journalid[_n-1]!=journalid
replace jafdenominator = npapers[_n-1] if journalid[_n-2]!=journalid & journalid[_n-1]==journalid
replace jafdenominator = npapers[_n-1] + npapers[_n-2] if journalid==journalid[_n-1] & journalid==journalid[_n-2]
keep journalid jafdenominator year
compress
duplicates drop
save magjafdenominator, replace

use $mag/pcs, clear
rename patent patnum
drop if confscore<5
drop reftype confscore
fmerge m:1 patnum using $pv/patnumappyearfirmpat, keep(3) nogen
keep if patfirm==1
rename appyear  citingyear
rename  paperid magid
fmerge m:1 magid using $mag/magyear, keep(3) nogen
rename year citedyear
compress
* keep the uncited papers in every journal
drop if citingyear - citedyear>2
drop if citingyear==citedyear
drop if citingyear<citedyear
fmerge m:1 magid using $mag/magjournalid, keep(3) nogen
rename magid citedmagid
drop citedmagid
* for each pair, which year could that citation contribute to
* orif not cite, how many papers were ther ein two pervious years
* collapse to get the totals
* then do the division to get jaf
* rehape at that point ? i htink yes.
sort journalid citedyear citingyear
gen int journalyearpaircite = 1
replace journalyearpaircite = journalyearpaircite + journalyearpaircite[_n-1] if (journalid==journalid[_n-1] & citedyear==citedyear[_n-1] & citingyear==citingyear[_n-1])
* keep the FINAL journal/citingyear/citedyear observation (with the totals)
drop if (journalid==journalid[_n+1] & citedyear==citedyear[_n+1] & citingyear==citingyear[_n+1])
* you could optimize by collapsing down to the journal-cited-citing year level, then changing the following logic to
* create the variables and then just increment them
sort journalid
* 1947 is the first year of front-page patent citations
forvalues i = 1947/2018 {
  di "adding year `i'"
  gen int jafcite`i' = 0
  replace jafcite`i' =  journalyearpaircite if ((citingyear==`i') & (citedyear==`i'-1 | citedyear==`i'-2))
  replace jafcite`i' = jafcite`i' + jafcite`i'[_n-1] if journalid==journalid[_n-1]
}
drop citingyear citedyear
drop journalyearpaircite
drop if journalid==journalid[_n+1]

** get to here, then you'll need to build a list of papres per journal per year (well prior two years)
reshape long jafcite, i(journalid) j(year)
compress
merge 1:1 journalid year using magjafdenominator, keep(1 3) nogen
gen jaf = jafcite/jafdenominator
gen jafnomiss = jaf
replace jafnomiss = 0 if missing(jaf)
save $mag/journalidyearjaf, replace
use $mag/magyear, clear
merge 1:1 magid using $mag/magjournalid, keep (1 3) nogen
merge m:1 journalid year using $mag/journalidyearjaf, keep(1 3) nogen
keep magid jaf
replace jaf = 0 if missing(jaf)
compress
save $mag/magjaf, replace

use $mag/journalidyearjaf, clear
merge m:1 journalid using $mag/journalidname, nogen
drop journalid
compress
// rename year journalyear
drop jafcite  jafnomiss
rename jafdenominator prior2yrsnumpapers
save $mag/magjaf, replace
use $mag/magjaf, clear
rename jaf jcif
drop if missing(jcif)
sort journalname year
gen jcif3yr = .
gen consecutive =  (journalname==journalname[_n-1] & journalname==journalname[_n-2]) & (year==year[_n-1]+1 & year==year[_n-2]+2)
replace jcif3yr = (jcif + jcif[_n-1] + jcif[_n-2])/3 if consecutive==1
drop consecutive
compress
order year jcif jcif3yr journalname
save $mag/magjcif, replace
export delimited magjcif, replace



