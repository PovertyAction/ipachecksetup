# IPACHECKSETUP

## Overview

``ipachecksetup`` is a stata program that prefills the ipa HFC excel inputs template automatically for a survey. ``ipachecksetup`` takes the ipa HFC excel input template and fill in the template using the SurveyCTO questionnaire XLSForm. This program produces an HFC excel input file, however, further edits are required such as adding logic checks or specifying correction sheets etc. The program does not fill in Progress Report specifics which will require manual modification. Read further about HFC excel input file at <a href="https://github.com/PovertyAction/high-frequency-checks" target="_blank">ipa github page</a>. 

<b>After running the program, remember to manually deactivate the checks in <i>"0. setup"</i> sheet that do not need to be run. Otherwise, this will produce errors while running the HFC do file.</b> 


## Installation
```stata
* ipachecksetup can be installed from github

net install ipachecksetup, all replace ///
	from("https://raw.githubusercontent.com/PovertyAction/ipachecksetup/master")
```

## Syntax
```stata
ipachecksetup using filename, [template(string)] outfile(string) prefix() [options]
```

To open dialogue box, type: ``db ipachecksetup``



``filename`` can be xls or xlsx. If ``filename`` is specified without an extension, .xls or xlsx is assumed. Specify the path and file name of the SurveyCTO XLSForm. If ``filename`` contains embedded spaces, enclose it in double quotes.

``template`` is optional. Specify the path and file name of ipa HFC input Excel template to be used. If ``template`` is not specified, the template will be downloaded from <a href="https://github.com/PovertyAction/high-frequency-checks" target="_blank">ipa github page</a>, which also requires Internet connection.

``outfile`` is the filled in HFC input file. If ``outfile`` is specified without an extension, .xlsm is assumed. If ``outfile`` contains embedded spaces, enclose it in double quotes. Specify the path and file name of the filled in HFC input file.

``outfolder`` is optional. Specify the folder path where the HFC output files will be saved. If not specified, the folder of the filled in HFC input file will be assumed.

``prefix`` is a short prefix (i.e., project initial) that will be added with the HFC output files. For example, ``prefix(ipa)`` is specified, the HFC will produce these files:

| Description | File name |
| ---        |    ----   |
| HFC Output File | ipa_hfc_output.xlsx |
| HFC Enumerator File | ipa_enumdb.xlsx |
| HFC Text Audit File | ipa_text.xlsx |
| Survey Duplicate Output File | ipa_duplicates.xlsx |
| Back Check Comparison Output | ipa_bc.xlsx |
| HFC Research File | ipa_research.xlsx |


## Options
| Options      | Description |
| ---        |    ----   |
 | replace |  Replace ``outfile`` if already exists. | 
 | long  |  Assume data is in long format. Specify this if either your data is in long format, or there is no repeat group. | 
 | wide  |  Assume data is in wide format. Specify this if either your data is in wide format, or there is no repeat group. If wide is specified, the program adds variables inside repeat groups (if any) with * in prefix so that the ``ipacheck`` program considers all possible variables generated from the repeat group. However, this does not work for "8. constraints" and "9. specify" sheets, therefore, the program adds only the first repeat in these sheets, i.e., adds _1 prefix. For example, `var_1` if `var` is inside repeat group. |  
 | survey  |  Path and name of Survey Dataset. | 
 | media  |  Path of media directory for comments and text audits. | 
 | osp  |  Missing value for others. Only allows real number, if not specified -666 is assumed. If osp is not specified, the 9. specify sheet will not be populated. | 
 | <ins>ref</ins>usal |  Missing value for refusal. Only allows real number, if not specified -888 is assumed. | 
 | <ins>dontk</ins>now | Missing value for don't know. Only allows real number, if not specified -999 is assumed. |
 | na | Missing value for not applicable. Only allows real number, if not specified -222 is assumed. | 
 | consent |  Comma separated variables along with consent values. ``consent(consent 1, phone_response 1)``. If not specified, the program searches for any variable having "consent" in the name, and assumes it to be consent variable and 1 as consent value. | 
 | id  |  Survey ID. varlist allowed. | 
 | enumid   |  Enumerator ID. | 
 | teamid  |  Enumerator Team ID. | 
 | incomplete  |  Comma separated variables along with complete value. ``incomplete(consent 1, phone_response 1)``. If not specified, the program searches for any variable having "consent" in the name, and assumes it to be incomplete variable and 1 as complete value. `complete_percent` is assumed to be 100. | 
 | surveystart |  Survey Start date (MM/DD/YYYY). ``surveystart(9/14/2020)``. | 
 | label  |  Label language (Specify if multiple languages exist in XLS form). Case sensative. If in SurveyCTO XLSForm it is defined as ``label::English`` or ``label:English``, specify ``label(English)``. Do not specify `label` if SurveyCTO XLSForm only has one `label` column. | 
 | <ins>mul</ins>tiplier  |  Multiplier for outliers followed by SD. If not specified 3 is assumed. This will be assigned to all variables. If you need to change multiplier value for certain variable(s), please edit the HFC input excel temlate after running the program. If ``sd`` is specified, SD will be used, instead of Interquantile Range. To use SD: ``multiplier(3, sd)``. To use Interquantile Range ``multiplier(3)``. | 
 | softmin  |  Soft minimum constraint (default is 10, i.e., 10% increased value from hard min). Hard min is taken from the constraints in SurveyCTO XLSForm. If the SurveyCTO form does not have a minimum constraint, hard min and soft min will not be populated. Please manually add them or modify specific variables after running the program, if required. | 
 | softmax |  Soft maximum constraint (default is 10, i.e., 10% decreased value from hard max). Hard max is taken from the constraints in SurveyCTO XLSForm. If the SurveyCTO form does not have a maximum constraint, hard max and soft max will not be populated. Please manually add them or modify specific variables after running the program, if required. | 
 | r1  |  Research oneway variables. Varlist is allowed. ``r1(community age father_job)``. If nothing specifies, the program populates all possible variables. | 
 | r2  |  Research twoway variables. Varlist followed by a comma and by variable. ``r2(community age father_job, gender)`` | 
 | bcid  |  Back Checker ID. | 
 | bcteamid  |  Back Checker team ID. | 
 | <ins>back</ins>check  |  Back Check SurveyCTO XLS form. Backcheck variables will be populated from the XLSForm. However, type and other specifications need to be done manually after the output file is saved. | 





## Example Syntax
```stata
* Long Formatted Dataset
ipachecksetup using "Endline Survey.xlsx", ///
	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_endline.xlsm") ///
	long prefix("ipa")

* Wide Formatted Dataset
ipachecksetup using "Endline Survey.xlsx", ///
	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_endline.xlsm") ///
	wide prefix("ipa")

* Using all options
ipachecksetup using "ipa_yop_2017_short_DRAFT.xlsx", ///
	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_yop") 	///
	wide replace prefix("yop") ///
		label(English) ///
		osp(-96) ref(-98) dontk(-99) na(-22) ///
		softmin(15) softmax(40) mul(1.3, sd) ///
		id(uid1) consent(consent 1, phone_response 1) ///
		incomplete(consent 1) ///
		surveystart(9/14/2020)  ///
		enumid(enumid) teamid(superid) ///
		survey("ipa_yop_2017_data.dta") ///
		r1(community age father_job) r2(community age father_job, gender) ///
		media("..\raw\media")  ///
		backcheck("ipa_yop_2017_backcheck.xlsx") 

```

Please report all bugs/feature request to the <a href="https://github.com/PovertyAction/ipachecksetup/issues" target="_blank"> github issues page</a>
