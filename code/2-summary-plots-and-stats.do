//yeet


cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433


use data/intermediate/merged_allMSAs_allind, clear
keep if msatype == "Metro"

//summarize FFRDC count per MSA per year
tab ffrdc year //TO DO: investigate why the number of MSAs increases between 1979 and 1990
//to do: investigate instances of changes in number of FFRDCs
tab2xl ffrdc year if year >= 1979 & year < 1990 using output/msa_ffrdc_counts_1.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 1990 & year < 2000  using output/msa_ffrdc_counts_2.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 2000 & year < 2010 using output/msa_ffrdc_counts_3.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 2010 using output/msa_ffrdc_counts_4.xlsx, replace col(1) row(1)


//summarize causal and outcome variables
//http://repec.sowi.unibe.ch/stata/estout/estpost.html
gen has_ffrdc = ffrdc > 0
label define has_ffrdc_values 0 "no FFRDC" 1 "with FFRDC"
label values has_ffrdc has_ffrdc_values

//to do: make these transformations sometime earlier
sort year has_ffrdc
replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000000 
label variable annual_avg_emplvl "Annual average of total employment (million)"
replace dataFederal = dataFederal / 1000000
label variable dataFederal "Total federal FFRDC funding received (millions 2019$)"

estimates clear
eststo: estpost summarize avg_annual_pay annual_avg_emplvl dataFederal if year >= 2001
esttab using output/summarystats.csv, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") label nodepvar replace

//histograms
hist avg_annual_pay if year >= 2001, title("Wages across all MSAs, 2001-2009")
hist annual_avg_emplvl if year >= 2001, title("Employment across all MSAs, 2001-2009")
hist dataFederal if year >= 2001 & ffrdc >0, title("FFRDC funding across MSAs with at least one FFRDC," "2001-2009")

//split summary by year and by FFRDC presence
estimates clear
keep if year == 2019 | year == 2010 | year == 2001
//to do: fix labelling and make prettier
by year has_ffrdc: eststo: estpost summarize avg_annual_pay annual_avg_emplvl dataFederal, listwise
esttab using output/summarystats_by_year_ffrdc.csv, cells("mean(fmt(2)) sd(fmt(2))") label nodepvar replace


use data/intermediate/merged_allMSAs_allind_post01, clear
replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000000 
label variable annual_avg_emplvl "Annual average of total employment (million)"
replace dataFederal = dataFederal / 1000000
label variable dataFederal "Total federal FFRDC funding received (millions 2019$)"

//OLS regression 
encode msacode, gen(msa_factor)

reg avg_annual_pay dataFederal, robust
outreg2 using output/ols_avg_annual_pay.doc, replace keep(dataFederal) addtext(MSA FE, No, Year FE, No, FFRDC count FE, No)
reg avg_annual_pay dataFederal i.msa_factor, robust
outreg2 using output/ols_avg_annual_pay.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
reg avg_annual_pay dataFederal i.year i.msa_factor, robust
outreg2 using output/ols_avg_annual_pay.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, No)
reg avg_annual_pay dataFederal i.year i.msa_factor i.ffrdc_count, robust
outreg2 using output/ols_avg_annual_pay.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

reg annual_avg_emplvl dataFederal, robust
outreg2 using output/ols_annual_avg_emplvl.doc, replace keep(dataFederal) addtext(MSA FE, No, Year FE, No, FFRDC count FE, No)
reg annual_avg_emplvl dataFederal i.msa_factor, robust
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
reg annual_avg_emplvl dataFederal i.year i.msa_factor, robust
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, No)
reg annual_avg_emplvl dataFederal i.year i.msa_factor i.ffrdc_count, robust
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(dataFederal) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)
