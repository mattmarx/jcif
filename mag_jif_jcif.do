set more off

* globals ending in 'tsv' need to be set to where those files are located
* other globals are for convenience in keeping directories clean

global magtsv "../../bigdata/mag/txt"
global pcs "./"
global pvtsv "../../bigdata/patents/patentsview/"
global pv "./"
global mag "./"
global output "./"


********************************
** Import necessary databases **
********************************

	*** import PatentsView files and save them as Stata ***
	
	import delimited using $pvtsv/patent.tsv, clear varnames(1)
	keep number
	rename number patnum
	duplicates drop
	save $pv/patnum, replace
	
	import delimited using $pvtsv/application.tsv, clear varnames(1)
	keep patent_id date
	rename patent_id patnum
	gen appyear = regexs(1) if regexm(date, "^([0-9][0-9][0-9][0-9])")
	destring appyear, replace
	drop date
	merge 1:1 patnum using patnum, keep(3) nogen
	save $pv/patnumappyear, replace
	
	import delimited using $pvtsv/assignee.tsv, clear varnames(1)
	gen firmassignee = 0
	replace firmassignee = 1 if type==2
	replace firmassignee = 1 if type==3
	keep id firmassignee
	rename id assigneeid
	save $pv/assigneeisfirm, replace
	
	* type: irms = 1,3
	import delimited using $pvtsv/patent_assignee.tsv, clear varnames(1)
	rename assignee_id assigneeid
	rename patent_id patnum
	save $pv/patent_assigneeid, replace
	
	use patent_assigneeid, clear
	merge m:1 assigneeid using assigneeisfirm, keep(3) nogen
	bys patnum: egen pctfirmassignees = mean(firmassignee)
	keep patnum pctfirmassignees
	duplicates drop
	save $pv/pctpatfirmassigned, replace
	
	use patnumappyear, clear
	merge 1:1 patnum using pctpatfirmassigned, keep(3) nogen
	gen patfirm = pctfirmassignees>0
	drop pctfirmassignees
	save $pv/patnumappyearfirmpat, replace

	*** import Microsoft Academic Graph (MAG) files and save as STata

	import delimited using $magtsv/paperyear.tsv, clear varnames(1)
	rename paperid magid
	rename paperyear year
	save $mag/magyear, replace
	
	import delimited using $magtsv/paperjournalid.tsv, clear varnames(1)
	rename paperid magid
	save $mag/magjournalid, replace
	
	import delimited using $magtsv/paperjournalid.tsv, clear varnames(1)
	rename paperid magid
	save $mag/magjournalid, replace

	import delimited using $magtsv/journalidname.tsv, clear varnames(1)
	drop journalname
	rename v3 journalname
	save $mag/journalidname, replace
	
	import delimited using $magtsv/papercitations.tsv, clear varnames(1)
	save $mag/magcitations, replace

	import delimited using $pcs/pcs.tsv, clear varnames(1)
	save $mag/pcs, replace


************************
** Create 2-year JCIF **
************************

	** Create JCIF denominator **

	use $mag/magyear, clear

	fmerge 1:1 magid using $mag/magjournalid, keep(3) nogen

	gen int npapers = 1

	gcollapse (sum) npapers, by(year journalid)

	sort journalid year

	// Filling the gaps in years
	g ydif= year-year[_n-1] if journalid==journalid[_n-1]
	sum ydif // Max gap is 207

	forval i=207(-1)2{
	expand 2 if ydif==`i', g(ind`i')
	replace npapers=0 	if ind`i'==1
	replace year=year-1 	if ind`i'==1
	drop ydif ind`i'
	sort journalid year
	g ydif= year-year[_n-1] if journalid==journalid[_n-1]
	}

	// Adding 2 extra years from the last observation (ndicator considers 
	egen y_max=max(year), by(journalid)

	expand 2 if year==y_max, g(ind1)
	sort journalid year 
	replace year=year+1 	if ind1==1
	replace npapers=0	if ind1==1
	sort journalid year

	expand 2 if year==(y_max+1), g(ind2)
	sort journalid year
	replace year=year+1 	if ind2==1
	replace npapers=0 	if ind2==1
	sort journalid year

	drop y_max ind1 ind2 ydif

	// Computing the number of papers published in the previous 2 years
	egen j_id=tag(journalid)

	g jafdenominator= npapers[_n-1] + npapers[_n-2] 	if year==(1+year[_n-1]) & year==(2+year[_n-2]) & journalid==journalid[_n-1] & journalid==journalid[_n-2]
	replace jafdenominator= npapers[_n-1] 			if jafdenominator==. & (year-2)<=year[_n-1] & journalid==journalid[_n-1] & j_id!=1
	replace jafdenominator=0				if jafdenominator==.

	keep journalid jafdenominator year 

	compress

	drop if journalid==. // Drop the papers that have not a journal associated

	save $output/magjcifdenominator, replace
		
	** Create JCIF numeranator **

	use $mag/pcs, clear
	
	rename patent patnum
	
	drop if confscore<5 // 539,781 of 15,697,871 (3.4%) 
	drop reftype confscore
	
	fmerge m:1 patnum using $pv/patnumappyear, keep(3) nogen

	drop patnum
	
	rename appyear  citingyear
	rename  paperid magid
	
	fmerge m:1 magid using $mag/magyear, keep(3) nogen
	
	rename year citedyear
	
	compress

	fmerge m:1 magid using $mag/magjournalid, keep(3) nogen

	gcollapse (count) n_papers=magid, by(journalid citingyear citedyear)

	sort journalid citingyear citedyear 

	g paper_2y = n_papers if 2>=(citingyear - citedyear) & (citingyear - citedyear)>0
	replace paper_2y = 0 if paper_2y==.

	gcollapse (sum) jafcite=paper_2y, by(journalid citingyear)

	rename citingyear year

	drop if journalid==.

	keep journalid year jafcite

	save $output/magjafnumerator, replace
	
	** Create 2-year JCIF **

	use $output/magjafnumerator, clear

	fmerge 1:1 journalid year using $output/magjcifdenominator, nogen // Should have no restrictions. If we restrict to (1 3) we are not incorporating non-zero denominators (which is important if we want to control by size of the journal).

	gen jaf = jafcite/jafdenominator

	gen jafnomiss = jaf
	replace jafnomiss = 0 if missing(jaf)

	compress

	save $output/journalidyearjaf, replace

	fmerge m:1 journalid using $mag/journalidname, nogen

	compress

	rename jafdenominator prior2yrsnumpapers

	save $output/magjaf.dta, replace

	rename jaf jcif

	drop if missing(jcif) & (prior2yrsnumpapers==0 | prior2yrsnumpapers==.)  // There is some gain of maintaining some of the missing values, some of them shoul be zero instead of 0 if the denominator is diff than zero or missing.

	sort journalid year // Should be journalid as journalname has duplicates with the same journalid

	replace jcif = 0 if missing(jcif)

	gen consecutive =  (journalid==journalid[_n-1] & journalid==journalid[_n-2]) & (year==year[_n-1]+1 & year==year[_n-2]+2)

	gen jcif3yr = .
	replace jcif3yr = (jcif + jcif[_n-1] + jcif[_n-2])/3 if consecutive==1

	drop consecutive

	compress

	order journalid journalname  year jcif jcif3yr 
        
	save $output/magjcif.dta, replace
        keep journalid journalname year jcif
        save $output/jcif.dta, replace
        export delimited using $output/jcif.tsv, delimiter(tab)
        !zip jcif jcif.tsv
	

***********************
** Create 2-year JIF **
***********************

	** Creating JIF denominator **

	use "$mag/magjournalid.dta", clear

	fmerge 1:1 magid using "$mag/magyear.dta", nogen

	sort journalid year

	gcollapse (count) n_papers=magid, by(journalid year)

	// Filling the gaps
	g ydif= year-year[_n-1] if journalid==journalid[_n-1]
	sum ydif

	forval i=207(-1)2{
	expand 2 if ydif==`i', g(ind`i')
	replace n_papers=0 	if ind`i'==1
	replace year=year-1 	if ind`i'==1
	drop ydif ind`i'
	sort journalid year
	g ydif= year-year[_n-1] if journalid==journalid[_n-1]
	}

	// Adding 2 extra years from the last observation 
	egen y_max=max(year), by(journalid)

	expand 2 if year==y_max, g(ind1)
	sort journalid year 
	replace year=year+1 	if ind1==1
	replace n_papers=0	if ind1==1
	sort journalid year

	expand 2 if year==(y_max+1), g(ind2)
	sort journalid year
	replace year=year+1 	if ind2==1
	replace n_papers=0 	if ind2==1
	sort journalid year

	drop y_max ind1 ind2 ydif

	drop if year>2019
	 
	egen j_id=tag(journalid)

	//Note: According to JIF, the denominator is "the total number of "citable items" published by that journal in t-2 and t-1." 
	//Note: Difference between this code and the JCIF code (lines 72 and 73). The difference relies on that JCIF code does not ensures that the previous data entries correspond to years t-2 and t-1. 

	g d_paper_2y= n_papers[_n-1] + n_papers[_n-2] 	if year==(1+year[_n-1]) & year==(2+year[_n-2]) & journalid==journalid[_n-1] & journalid==journalid[_n-2]
	replace d_paper_2y= n_papers[_n-1] 		if d_paper_2y==. & (year-2)<=year[_n-1] & journalid==journalid[_n-1] & j_id!=1
	replace d_paper_2y=0				if d_paper_2y==.

	keep journalid year d_paper_2y

	drop if journalid==.

	save "$output/citations_denominator.dta", replace

	** Create JIF numerator **

	// Merging citing and date databases
	use "$mag/magcitations.dta", clear

	rename citedpaperid magid

	merge m:1 magid using "$mag/magyear.dta", keep(1 3) nogen // 133,800,911 data points of using not matched

	rename magid citedmagid
	rename year citedyear 
	rename citingpaperid magid

	merge m:1 magid using "$mag/magyear.dta", keep(1 3) nogen

	rename magid citingmagid 
	rename year citingyear 

	save "$output/citations_merge.dta", replace

	rename citedmagid magid

	merge m:1 magid using "$mag/magjournalid.dta", keep(1 3) nogen

	drop if journalid==. 
	
	rename magid citedmagid 

	compress 

	collapse (count) n_papers=citedmagid, by(journalid citingyear citedyear)

	sort journalid citingyear citedyear 

	g n_paper_2y = n_papers		if 2>=(citingyear - citedyear) & (citingyear - citedyear)>0
	replace n_paper_2y = 0 		if n_paper_2y==.

	gcollapse (sum) n_paper_2y, by(journalid citingyear)

	rename citingyear year

	drop if journalid==.

	save "$output/citations_numerator.dta", replace

	** Creating 2-year JIF **

	use "$output/citations_denominator.dta", clear

	fmerge 1:1 journalid year using "$output/citations_numerator.dta", nogen

	g jif_1=n_paper_2y/d_paper_2y

	g jif_1nomiss=jif_1  
	replace jif_1nomiss=0 if missing(jif_1nomiss)

	label variable jif_1 "JIF considering all observations"
	label variable jif_1nomiss "JIF considering all observations & non-zero"

	fmerge m:1 journalid using "$mag/journalidname.dta", nogen

	save "$output/citations_jif.dta", replace

	rename jif_1 jif_2

	label variable jif_2 "JIF considering non-zero denominators"

	drop if missing(jif_2) & (d_paper_2y==0 | d_paper_2y==.) 

	sort journalid year
	replace jif_2 = 0 if missing(jif_2)
	gen jif_2_3yr = .
	gen consecutive =  (journalid==journalid[_n-1] & journalid==journalid[_n-2]) & (year==year[_n-1]+1 & year==year[_n-2]+2)
	replace jif_2_3yr = (jif_2 + jif_2[_n-1] + jif_2[_n-2])/3 if consecutive==1
	drop consecutive
	compress
	order journalid journalname  year jif_2 jif_2_3yr
	save "$output/citations_jif_mod.dta", replace
        keep journalid journalname year jif_2
        rename jif_2 jif
        compress
        save $output/jif, replace
	export delimited using $output/jif.tsv, delimiter(tab)
        !zip jif jif.tsv


************************************
** Merge and compare against JCIF **
************************************

use "$output/citations_jif_mod.dta", clear

merge 1:1 journalid journalname year using "$output/magjcif.dta", nogen

order journalid journalname year jif_2 jif_2_3yr jcif jcif3yr d_paper_2y

save "$output/mag_jcif_jif.dta", replace
