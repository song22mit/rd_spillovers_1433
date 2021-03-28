//yeet

cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

//-------------read in and standardize FFRDC data---------
//seed the append loop
clear
set obs 1
gen x=.
save data/intermediate/ffrdcrd_all, replace

forvalues yr = 1979(1)2019 {
    display `yr'
    import delimited data/raw/FFRDC/ffrdcrd`yr'.csv, clear
	display("questionnaire_no")
	if (`yr' < 1997 | inrange(`yr',2002,2009)) {
	    gen questionnaire_string = string(questionnaire_no, "%02.0f")
		drop questionnaire_no
		ren questionnaire_string questionnaire_no
	}
	display("inst_zip")
	if `yr' < 2001 {
	    gen zip_string = string(inst_zip, "%05.0f")
		drop inst_zip
		ren zip_string inst_zip
	}
	display("column")
	if inrange(`yr',2002,2009) {
	    gen column_string = string(column)
		drop column
		ren column_string column
	}
	display("status")
	if (inrange(`yr',2004,2010) | `yr' >= 2017) {
	    gen status_string = string(status)
		drop status
		ren status_string status
	}
	append using data/intermediate/ffrdcrd_all
	save data/intermediate/ffrdcrd_all, replace
}

//drop seed observation
drop if year == .
drop x
save data/intermediate/ffrdcrd_all, replace

//TO DO: investigate status variable (missing/imputed data)

/*
//standardize FFRDC names
replace inst_name_long = regexr(inst_name_long, "'","")
replace inst_name_long = regexr(inst_name_long, "&","and")
replace inst_name_long = regexr(inst_name_long, "Natl ","National ")
replace inst_name_long = regexr(inst_name_long, "Lab","Laboratory") if substr(inst_name_long, -3, 3) == "Lab"
replace inst_name_long = regexr(inst_name_long, "Lab","Laboratory")
replace inst_name_long = regexr(inst_name_long, "Laboratories","Laboratory")
replace inst_name_long = regexr(inst_name_long, "C31","C3I")
replace inst_name_long = "Lincoln Laboratory" if regexm(inst_name_long, "Lincoln Laboratory")
replace inst_name_long = "Princeton Plasma Physics Laboratory" if regexm(inst_name_long, "Plasma Physics")
replace inst_name_long = "National Astronomy and Ionosphere Center" if regexm(inst_name_long, "Ionos")
replace inst_name_long = "Science and Technology Policy Institute" if regexm(inst_name_long, "Science and Technology Policy Institute")
replace inst_name_long = "Frederick Cancer Research and Development Center" if regexm(inst_name_long, "Cancer")
replace inst_name_long = "Brookhaven National Laboratory" if regexm(inst_name_long, "Brookhaven")
replace inst_name_long = "Software Engineering Institute" if regexm(inst_name_long, "Software Engineering")
replace inst_name_long = "Lawrence Berkeley National Laboratory" if regexm(inst_name_long, "Lawrence Berkeley")
replace inst_name_long = "Center for Enterprise Modernization" if regexm(inst_name_long, "Internal Revenue Service") | regexm(inst_name_long, "IRS")
//TO CONTINUE: run lines 70-74 and then the above section and then 73 again

save data/intermediate/ffrdcrd_all, replace
nmissing


use data/intermediate/ffrdcrd_all, clear
keep inst_name_long inst_city inst_state inst_zip year
sort inst_zip inst_name_long
duplicates drop inst_name_long inst_city inst_zip, force
*/


//--------------------crosswalk FFRDC data to county-----------------------------
//import crosswalk file, keep only zips with a unique county, merge to FFRDC data by zip
import excel data/raw/COUNTY_ZIP_122020.xlsx, firstrow clear
duplicates tag ZIP, gen(dup)
drop if dup > 0
drop dup
save data/intermediate/zip_to_county_unique, replace

use data/intermediate/ffrdcrd_all, clear
rename inst_zip ZIP
replace ZIP = substr(ZIP,1,5)
merge m:1 ZIP using data/intermediate/zip_to_county_unique, keepusing(COUNTY)
drop if _merge == 2

//handcode counties where there is no unique county for that zip
replace COUNTY = "25017" if inst_city == "Lexington"
replace COUNTY = "51013" if inst_city == "Arlington"
replace COUNTY = "51510" if inst_city == "Alexandria"
replace COUNTY = "51003" if inst_city == "Charlottesville"
replace COUNTY = "17043" if inst_city == "Argonne"
replace COUNTY = "48453" if inst_city == "Austin"
replace COUNTY = "16019" if inst_city == "Idaho Falls"
replace COUNTY = "35028" if inst_city == "Los Alamos"
replace COUNTY = "06037" if inst_city == "Santa Monica"
replace COUNTY = "06001" if inst_city == "Livermore"
drop if ZIP == "99999"

drop _merge
save data/intermediate/ffrdcrd_all, replace


//---------------------------summarize relevant ffrdc data------------------------
//filter only total funding and federal funding
use data/intermediate/ffrdcrd_all, clear
tab question year
keep if question == "Source"
tab row year
keep if row == "Federal government" | row == "Total"
replace row = "Federal" if row == "Federal government" 
drop questionnaire_no status question
reshape wide data, i(year inst_name_long COUNTY) j(row) string

//calculate total funding by county by year and number of ffrdcs by county by year
gen ffrdc_count = 1
collapse (sum) dataTotal dataFederal ffrdc_count, by(COUNTY year)
fillin COUNTY year
recode data* ffrdc_count (. = 0)
drop _fillin
save data/intermediate/ffrdcrd_county_summary, replace

//-------------read in and standardize QECW data---------
//identify relevant counties
use data/intermediate/ffrdcrd_county_summary, clear
keep COUNTY
duplicates drop
save data/intermediate/ffrdcrd_county_list, replace

//seed the append loop
clear
set obs 1
gen x=.
save data/intermediate/qcew_relevantcounties_allind, replace

//read in and append QCEW data
forvalues yr = 1975(1)2019 {
    display `yr'
	if `yr' <= 2015{
		import delimited "data/raw/QCEW/`yr'.annual 10 Total, all industries.csv", clear
	}
	else {
		import delimited "data/raw/QCEW/`yr'.annual 10 10 Total, all industries.csv", clear
	}
	
	//keep only counties with a FFRDC at some point in 1979-2019 and only totals (not by ownership)
	rename area_fips COUNTY
	merge m:1 COUNTY using data/intermediate/ffrdcrd_county_list
	keep if _merge == 3
	keep if agglvl_title == "County, Total Covered"
	drop oty*
	
	
	if inrange(`yr', 1990, 2000) {
		gen disclosure_code_string = string(disclosure_code)
		gen lq_disclosure_code_string = string(lq_disclosure_code)
		drop disclosure_code lq_disclosure_code
		ren disclosure_code_string disclosure_code
		ren lq_disclosure_code_string lq_disclosure_code
	}
	append using data/intermediate/qcew_relevantcounties_allind
	save data/intermediate/qcew_relevantcounties_allind, replace
}

//TO DO: investigate disclosure code (missing data)
//NOTE: disclosure_code = N means missing data
recode annual* avg_annual_pay lq_a* lq_t* (0 = .) if disclosure_code == "N"

drop _merge
//drop seed observation
drop if year == .
drop x
save data/intermediate/qcew_relevantcounties_allind, replace


// --------------- merge qcew with ffrdc data -------------------------
use data/intermediate/qcew_relevantcounties_allind, clear
merge 1:1 year COUNTY using data/intermediate/ffrdcrd_county_summary
save data/intermediate/merged_relevantcounties_allind, replace