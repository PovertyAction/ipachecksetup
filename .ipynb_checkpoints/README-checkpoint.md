# IPACHECKSETUP

## Overview

ipachecksetup is a stata program that prefills the IPA HFC inputs template.


## Installaion
```stata
* ipachecksetup can be installed from github

net install ipachecksetup, all replace ///
	from("https://raw.githubusercontent.com/PovertyAction/ipachecksetup/master")
```

## Syntax
```stata
ipachecksetup using filename, template(string) outfile(string) [replace long wide]
```



## Options
| Options      | Description |
| ---        |    ----   |
| template      |  template file for HFC inputs |
| outfile  |  save prefilled inputs file as |
| outfile  |  save prefilled inputs file as | 
	 | replace |  replace outfile if neccesary | 
	 | long  |  assume data is in long format. Only needed if forms has repeat groups | 
	 | wide  |  assume data is in wide format. Only needed if forms has repeat groups |  
	 | survey  | - path and name of Survey Dataset | 
	 | media  | - path of media directory | 
	 | osp  | - Missing value for others (default is -666) | 
	 | refusal | - Missing value for refusal (default is -888) | 
	 | dontknow | - Missing value for don't know (default is -999) | 
	 | consent | - consent variable and value | 
	 | id  | - Survey ID | 
	 | enumid   | - Enumerator ID | 
	 | teamid  | - Enumerator Team ID | 
	 | incomplete  | - Incomplete variable and value | 
	 | surveystart | - Survey Start date (MM/DD/YYYY) | 
	 | label  | - Label language (Specify if multiple languages exist in XLS form) | 
	 | multiplier  | - Multiplier for outliers | 
	 | softmin  | - Soft minimum constraint (default is 10, i.e., 10% increased value from hard min) | 
	 | softmax | - Soft maximum constraint (default is 10, i.e., 10% decreased value from hard max) | 
	 | r1  | - Research oneway variables | 
	 | r2  | - Research twoway variables | 
	 | bcid  | - Back Checker ID | 
	 | bcteamid  | - Back Checker team ID | 
	 | backcheck  | - Back Check SurveyCTO XLS form | 





## Example Syntax
```stata
* Long Formatted Dataset
ipachecksetup using "Endline Survey.xlsx", ///
	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_endline.xlsm") ///
	long 

* Wide Formatted Dataset
ipachecksetup using "Endline Survey.xlsx", ///
	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_endline.xlsm") ///
	wide

* Using all options
ipachecksetup using "ipa_yop_2017_short_DRAFT.xlsx", ///
 	template("hfc_inputs.xlsm") ///
	outfile("hfc_inputs_yop") 	///
	wide replace ///
		osp(-96) ref(-98) dontk(-99)  ///
		softmin(15) softmax(40) mul(1.3) ///
		id(uid1) consent(consent 1, phone_response 1) ///
		incomplete(consent 1) ///
		surveystart(9/14/2020)  ///
		enumid(enumid) teamid(superid) ///
		survey("ipa_yop_2017_data.dta") ///
		r1(community age father_job) r2(community age father_job, gender)  ///
		media("..\raw\media")
		backcheck("ipa_yop_2017_backcheck.xlsx") 

```

Please report all bugs/feature request to the [github issues page](https://github.com/PovertyAction/ipachecksetup/issues)
