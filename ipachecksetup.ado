*! Version 1.0.0 Ishmail Azindoo Baako and Mehrab Ali 19Sep2020
* Originally created by Ishmail Azindoo Baako (IPA) 24feb2018

/*
1. Incomplete: add incomplete() option // Done
2. Duplicates: Add id() option, not mendatory // Done
3. Consent: add consent(var, val) option, not mendatory  // Done
4. No miss: Check the code. Check the purpose
5. Follow up: Added variables specified in id() // Done
6. Logic: It pulls from the relevance. Looks good.
8. Constraint: Add hard min-max. Add softmin and softmax 10%+- of the value. // Done May be add an option to specify the percentage.
9. Dates: Add dates, option startsurvey(ddmmmyyyy) // Done
10. Specify: Looks good
11. Outlier: Looks good. May be add multuplier as option // Done
12. Text audit: Automatically create text audit groups, from begin group? Find inner groups? - Repeat groups do not need *. But add the begin repeat names
13. enumdb: pull duration variable from calculation, include stats variables , EXCLUDE NOTE FIELDS FROM EVERYWHERE // Added duration(), all integer and decimals for stats
14. Research db: option? // Done - varlist vs all
15. Backcheck: option? // Done

0. Setup: 
	1. Progress report options
Logic check:
	regular expressions not working - text fields excluded from logic checks
Text audit: Does not run for all groups
			Add media folder location - Done
Logic: For repeat group - tricky - added _1
Specify: Fix for repeat groups - added_1
Turning on and off

For repeat group add the _1 variable and add a note that for further variables, add manually - Done
What should we do for long data. A long term question, and should wait untill we solve the HFC input problem first.

*/

version 	12.0
cap program drop ipachecksetup
program define  ipachecksetup
	#d;
	syntax	using/, [template(string)] outfile(string) 
					[osp(real -666) REFusal(real -888) DONTKnow(real -999) 
					consent(string) id(string) incomplete(string) surveystart(string)
					MULtiplier(string) r1(string) r2(string) BACKcheck(string)
					replace long wide label(string) enumid(string) teamid(string) 
					bcid(string) bcteamid(string) survey(string) media(string) SOFTMIn(real 10) SOFTMAx(real 10)] 
		;
	#d cr

 	qui {
		loc label  label`label'

		* Setup URL
		loc git "https://raw.githubusercontent.com/PovertyAction"
		loc git_hfc "`git'/high-frequency-checks"
		loc branch master

		* tempfiles
		tempfile _choices _survey 

			* import choices data
			import excel using "`using'", sheet("choices") first allstr clear
				cap ren name value
				drop if missing(value) 
				replace `label' = ustrregexra(`label', "<.*?>", " " ) if strpos(`label',"<")  // Removing html tags
					* Converting common html entities
				replace `label' = ustrregexra(`label', "&nbsp;", "`=char(09)'	" ) if strpos(`label',"&nbsp;")
				replace `label' = ustrregexra(`label', "&lt;", "<" ) if strpos(`label',"&lt;")
				replace `label' = ustrregexra(`label', "&gt;", ">" ) if strpos(`label',"&gt;")
				replace `label' = ustrregexra(`label', "&amp;", "&" ) if strpos(`label',"&amp;")
			
			* save choices
			save `_choices', replace
		
			* import survey
			import excel using "`using'", sheet("survey") firstrow allstr clear
			cap ren relevant relevance
			
			* Fix GPS variables
			expand 2 if type=="geopoint", gen(geo)
			levelsof name if type=="geopoint", local(gpsvars) clean
			foreach var of local gpsvars {
				replace name = "`var'latitude" if name=="`var'" & geo==0
				replace name = "`var'longitude" if name=="`var'" & geo==1
			}
			
			drop if missing(type) | regexm(disabled, "[Yy][Es][Ss]") | type=="note"
			replace `label' = ustrregexra(`label', "<.*?>", " " ) if strpos(`label',"<")  // Removing html tags

			* Converting common html entities
			replace `label' = ustrregexra(`label', "&nbsp;", "`=char(09)'	" ) if strpos(`label',"&nbsp;")
			replace `label' = ustrregexra(`label', "&lt;", "<" ) if strpos(`label',"&lt;")
			replace `label' = ustrregexra(`label', "&gt;", ">" ) if strpos(`label',"&gt;")
			replace `label' = ustrregexra(`label', "&amp;", "&" ) if strpos(`label',"&amp;")
			save `_survey'

		* check if form includes repeat groups and ask user to specify long or wide option
		if "`long'`wide'" == "" {
			cap assert !regexm(type, "begin repeat|end repeat")
			if _rc {
				disp as err "must specify either long or wide option. XLS form contains repeat groups"
				exit 198 
			}
		}

		* check that both long and wide formats are not specified
		if "`long'" ~= "" & "`wide'" ~= "" {
			disp as err "options long and wide are mutually exclusive"
			exit 198
		}

		
		* Mark beginning and end of groups and repeats
		count if regexm(type, "group|repeat")

		gen grp_var 	= .
		gen rpt_grp_var = .

		gen begin_row 		= .
		gen begin_fieldname = ""
		gen end_row			= .
		gen end_fieldname 	= ""
		gen name_log		= name

		if `r(N)' > 0 {
			
			* generate _n to mark groups
			gen _sn = _n

			* get the name of all begin groups|repeat and check if the name if their pairs match
			levelsof _sn if (regexm(type, "^(begin)") & regexm(type, "group|repeat")), ///
				loc (_sns) clean
			
			count if (regexm(type, "^(begin)") & regexm(type, "group|repeat"))
			loc b_cnt `r(N)'
			count if (regexm(type, "^(end)") & regexm(type, "group|repeat"))
			loc e_cnt `r(N)'
			
			if `b_cnt' ~= `e_cnt' {
				di as err "Error in XLS form: There are `b_cnt' begin types and `e_cnt' end types"
				exit 198
			}
		
			foreach _sn in `_sns' {	

				if regexm(type[`_sn'], "group") loc gtype "grp"
				else loc gtype "rpt_grp"

				loc b 1
				loc e 0
				loc curr_sn `_sn'
				loc stop 0
				while `stop' == 0 {
					loc ++curr_sn 
					cap assert regexm(type, "^(end)") & regexm(type, "group|repeat") in `curr_sn'
					if !_rc {
						loc ++e
						if `b' == `e' {
							loc end `curr_sn'
							loc stop 1
						}
					}
					else {
						if "`gtype'" == "grp" replace grp_var = 1 in `curr_sn'
						if "`gtype'" == "rpt_grp" replace rpt_grp_var = 1 in `curr_sn'
						cap assert regexm(type, "^(begin)") & regexm(type, "group|repeat") in `curr_sn'
						if !_rc loc ++b
					}
				}

				replace begin_row 		= 	_sn[`_sn']		in `_sn'
				replace begin_fieldname =	name[`_sn']		in `_sn'
				replace end_row 		= 	_sn[`end']		in `_sn'
				replace end_fieldname 	=	name[`end']		in `_sn'
			}

			replace grp_var 	= 0 if missing(grp_var)
			replace rpt_grp_var = 0 if missing(rpt_grp_var)

			//replace name_log = subinstr(name, "_1", "", .) if (regexm(type, "^(begin)") & regexm(type, "group|repeat")) in `curr_sn'
			replace name = subinstr(name, "*", "", .) if (regexm(type, "^(begin)") & regexm(type, "group|repeat")) in `curr_sn'
		}
		
		gen newname = name
		* Check form for repeat groups and mark all repeat group variables
			
		* drop all repeat variables if long option is used
		if "`long'" ~= "" {
			drop if rpt_grp_var
			replace _sn = _n
			replace name_log = name  if rpt_grp_var
		}
			
		* include a wild card in repeat var names if option excluderepeats is not used
		if  "`wide'" ~= "" {
			replace name_log = name + "_1" if rpt_grp_var
			replace name = name + "*" if rpt_grp_var
			
		}


		* storing necessary variable names
		gen fieldcomments = cond(type[_n]=="comments", name[_n], "")
		levelsof fieldcomments, local(fieldcomments) clean
		gen textaudit = cond(type[_n]=="text audit", name[_n], "")
		levelsof textaudit, local(textaudit) clean
		drop fieldcomments textaudit
		save `_survey', replace

		noi disp
		noi disp "Prefilling HFC Inputs ..."

		//if !regex("`outfile'", ".xlsm$") loc outfile = regexr("`outfile'", "`outfile'", "`outfile'.xlsm") 
		loc outfile = regexr("`outfile'", ".xlsm", "")
		loc outfile =  "`outfile'.xlsm"


		if "`template'"!="" {
			copy "`template'" "`outfile'", `replace'
		}
		else {
			copy "`git_hfc'/`branch'/xlsx/hfc_inputs.xlsm" "`outfile'", `replace'
		}
		
		*00. setup
		clear
		set obs 40
		gen		data = "`survey'" 			in 1  // Dataset
		replace data = "`backcheck'" 		in 2 // BC dataset
		replace data = "`media'" 			in 4 // Media folder

		replace data = "`outfile'" 			in 7 // HFC & BC input file name
		loc outfile_dup = regexr("`outfile'", ".xlsm", "_duplicates.xlsx")
		loc outfile_hfc = regexr("`outfile'", ".xlsm", "_output.xlsx")
		loc outfile_hfc = regexr("`outfile_hfc'", "input", "")
		loc outfile_enum = regexr("`outfile'", ".xlsm", "_enumdb.xlsx")
		loc outfile_text = regexr("`outfile'", ".xlsm", "_text.xlsx")
		loc outfile_r = regexr("`outfile'", ".xlsm", "_research.xlsx")
		loc outfile_bc = regexr("`outfile'", ".xlsm", "_bc.xlsx")

		replace data = "`outfile_hfc'" 		in 12 //  file name
		replace data = "`outfile_enum'" 	in 13 // enumdb file name
		replace data = "`outfile_text'" 	in 14 // text audit file name
		replace data = "`outfile_dup'" 		in 16 // duplicate file name
		if "`backcheck'"!="" {
			loc outfile_bc = regexr("`outfile'", ".xlsm", "_BC.xlsx")
			replace data = "`outfile_bc'" 	in 17 // duplicate file name
		}
		replace data = "`outfile_r'" 		in 18 // research file name
		replace data = "submissiondate" 	in 22 // Submissiondate

		replace data = "`enumid'" 			in 24 // Enumerator ID
		replace data = "`teamid'" 			in 25 // Enumerator team ID
		replace data = "`fieldcomments'" 	in 28 // Field comments
		replace data = "`textaudit'" 		in 29 // Text audit
		replace data = "formdef_version" 	in 30 // Form version
		replace data = "`dontknow'" 		in 33 // missing (.d)
		replace data = "`refusal'" 			in 34 // missing (.r)


		tempfile setup
		save `setup'
		
		*01. incomplete
		if "`incomplete'"!="" {
			clear
				g complete_value = ""
				g name = ""
				g complete_percent = 100
				
			gettoken inc irest : incomplete, parse(",")
			
			loc i=1
			while `"`inc'"' != "" {
			if `"`inc'"' != "," {
				set obs `i'
				loc ivarname   : word 1 of `inc'
				local ivarvalue   : word 2 of `inc'			
				replace  name   = "`ivarname'" in `i'
				replace  complete_value   = "`ivarvalue'"  in `i'	
				}
				gettoken inc irest : irest, parse(",")
				loc ++i
			}
			drop if mi(name) & mi(complete_value)
			duplicates drop name complete_value, force

			tempfile incomp
			save `incomp'
			
			use `_survey', clear
			merge m:1 name using `incomp', gen(mergeincomp)

			* Check if variables exist
			levelsof name if mergeincomp==2, local(incomplist) clean
			count if mergeincomp==2	
				if r(N)>0 {
					noi di as err "`incomplist' does not exist"
					exit 111	
				}		

			keep if mergeincomp==3

				if _N > 0 {
				* export variable and value to incomplete sheet
				export excel name `label' complete_value complete_percent using "`outfile'", 							///
						sheet("1. incomplete") sheetmodify cell(A2)
				noi disp "... 1. incomplete complete"
				}		
		}

		if "`incomplete'"=="" {
				use `_survey', clear
				keep if regex(name, "consent")==1 & regex(type, "select_" "integer" "text")==1
				
				if `=_N' > 0 {
				g complete_value = 1
				g complete_percent = 100
				export excel name `label' complete_value complete_percent using "`outfile'", 							///
						sheet("1. incomplete") sheetmodify cell(A2)
				noi disp "... 1. incomplete complete"
				}
		}

		*02. duplicates
		if "`id'"!="" {
			use `_survey', clear
			gettoken arg rest : id, parse(",")
			local comb   : word 2 of `rest'
			gl surveyid = "`arg'"
			* Check if variables exist
			foreach var of local arg {
				count if newname == "`var'"
				if r(N)==0 {
					noi di as err "`var' does not exist"
					exit 111	
				}
				
			}


			if lower(stritrim("`comb'"))!="comb" & lower(stritrim("`comb'"))!="" {
				n di as err "id() wrongly specified."
				exit 198
			}

			if  lower(stritrim("`comb'"))==""  {
				loc arg = stritrim("`arg'")
				loc arg = ustrregexra("`arg'", " ", "|")
				export excel name `label' if regex(newname, "^(`arg')$")==1  using "`outfile'", 							///
				sheet("2. duplicates") sheetmodify cell(A2)
				noi disp "... 2. duplicates complete"
			}
		
			if lower(stritrim("`comb'"))=="comb" {
				clear 
				set obs 1
				gen name = stritrim("`arg'")
				export excel name using "`outfile'", 							///
				sheet("2. duplicates") sheetmodify cell(A2)
				noi disp "... 2. duplicates complete"
			}
		}
		*03. consent

		if "`consent'"!="" {
			clear
			gen name = ""
			gen consent_value = ""
			
			gettoken arg rest : consent, parse(",")
			
			loc i=1
			while `"`arg'"' != "" {
			if `"`arg'"' != "," {
				set obs `i'
				loc varname   : word 1 of `arg'
				local varvalue   : word 2 of `arg'			
				replace  name   = "`varname'" in `i'
				replace  consent_value   = "`varvalue'"  in `i'	
				}
				gettoken arg rest : rest, parse(",")
				loc ++i
			}
			drop if mi(name) & mi(consent_value)
			duplicates drop name consent_value, force

			tempfile consent
			save `consent'
			
			use `_survey', clear
			merge m:1 name using `consent', gen(mergeconsent)

			* Check if variables exist
			levelsof name if mergeconsent==2, local(consentlist) clean
			count if mergeconsent==2	
				if r(N)>0 {
					noi di as err "`consentlist' does not exist"
					exit 111	
				}		

			keep if mergeconsent==3
			* export variable and value to consent sheet
			export excel name `label' consent_value using "`outfile'", 							///
					sheet("3. consent") sheetmodify cell(A2)
			noi disp "... 3. consent complete"			
			}

			if "`consent'"=="" {
				use `_survey', clear
				keep if regex(name, "consent")==1 & regex(type, "select_" "integer" "text")==1
				
				if `=_N' > 0 {
				g consent_value = 1
				export excel name `label' consent_value using "`outfile'", 							///
				sheet("3. consent") sheetmodify cell(A2)
				noi disp "... 3. consent complete"
				}

		}

		* 04. no miss
		use `_survey', clear
		* Find variables to be added to no miss
		drop if inlist(type, "deviceid", "subscriberid", "simserial", "phonenumber", "username", "caseid")
		
		* keep only required or scto always generated vars
		//replace required = lower(required)
		keep if regexm(required, "[Yy][Ee][Ss]") | inlist(name, "starttime", "endtime", "duration")
		* drop all notes and fields with no relevance
		drop if type == "note" | !missing(relevance)

		* drop all variables in groups and repeats that have relevance expressions
		loc repeat 9
		while `repeat' == 9 { 
			gen n = _n
			levelsof name if !missing(relevance) & regexm(type, "begin"), ///
				loc (variables) clean 
			loc variable: word 1 of `variables'
			levelsof n if name == "`variable'", loc (indexes)
			loc start: 	word 1 of `indexes'
			loc end:	word 2 of `indexes'
			cap drop in `start'/`end'
				
			cap assert missing(relevance) if regexm(type, "begin")
			loc repeat `=_rc'
			drop n
		}


		* export variables to nomiss sheet. The first 2 cells will already contain key and skey
		export excel name `label' using "`outfile'", 							///
				sheet("4. no miss") sheetmodify cell(A2)
		noi disp "... 4. no miss complete"
		
		* 05. followup
		if "`id'"!="" {
			use `_survey', clear
			gettoken arg rest : id, parse(",")
			local comb   : word 2 of `rest'
			if  lower(stritrim("`comb'"))==""  {
				loc arg = stritrim("`arg'")
				loc arg = ustrregexra("`arg'", " ", "|")
				export excel name `label' if regex(newname, "^(`arg')$")==1  using "`outfile'", 							///
				sheet("5. follow up") sheetmodify cell(A2)
				noi disp "... 5. follow up complete"
			}
		
			if lower(stritrim("`comb'"))=="comb" {
				clear 
				set obs 1
				gen name = stritrim("`arg'")
				export excel name using "`outfile'", 							///
				sheet("5. follow up") sheetmodify cell(A2)
				noi disp "... 5. follow up complete"
			}
		
		}


		* 06. logic
		use `_survey', clear
		
		* Add group|repeat relevance to individual field within groups

		gen if_condition = ""
		replace relevance = subinstr(relevance, "$", "", .) if !missing(relevance)
		levelsof _sn if !missing(relevance) & regexm(type, "begin group|begin repeat"), ///
			loc (groups) clean
		foreach group in `groups' {
			gen n = _n
			loc start 	= _sn[`group']
			loc end 	= _sn[`group']
			loc relevance = relevance[`start']
			replace if_condition = if_condition + "\(" + "`relevance'" + ")" in `start'/`end'
			drop n
		}
			
		* drop all field without relevance
		drop if missing(relevance) | type == "note" | regexm(type, "group|repeat")
		if `=_N' > 0 {
			* to cater for no spaces in programming, add white space to either side of =
			* trim excess whitespace, change = to ==
			foreach var of varlist relevance if_condition {
				replace `var' = trim(itrim(subinstr(`var', "=", " # ", .)))
				replace `var' = subinstr(`var', "'", char(34), .)
				replace `var' = subinstr(`var', "> # ", ">= ", .)
				replace `var' = subinstr(`var', "< # ", "<= ", .)
				replace `var' = subinstr(`var', "! # ", "!= ", .)
				replace `var' = subinstr(`var', "{", "", .)
				replace `var' = subinstr(`var', "}", "", .)
				replace `var' = subinstr(`var', " and ", " & ", .)
				replace `var' = subinstr(`var', " or ", " | ", .)
				replace `var' = subinstr(`var', "\(", "", 1)
				replace `var' = subinstr(`var', "\", " & ", .)
				replace `var' = subinstr(`var', "\", " & ", .)
				replace `var' = subinstr(`var', "not(", "!(", .)
				replace `var' = subinstr(`var', ")", "", 1) if strpos(`var', "(") == 0 ///
					| (strpos(`var', "(") > strpos(`var', ")"))
				loc repeat = 9
				while `repeat' == 9 {
					gen sub = substr(`var', (strpos(`var', "#") + 2), 1)
					replace `var' = subinstr(`var', "#", "==", 1) if ///
						regexm(sub, "[0-9]|[-]") | regexm(sub, char(34))
					replace `var' = subinstr(`var', "#", "=", 1) if ///
						regexm(sub, "[a-zA-Z]") | regexm(sub, char(34))
					cap assert !regexm(`var', "#")
					loc repeat `=_rc'
					drop sub
				}
				* change selected and selected-at with regexm
				replace `var' = subinstr(`var', "count-selected", "wordcount", .)
				replace `var' = subinstr(`var', "selected-at", "regexm(string", .)
				replace `var' = subinstr(`var', "selected", "regexm(string", .)
				replace `var' = subinstr(`var', ", ", ",", .)
				replace `var' = ustrregexra(`var', ",", "\),"+char(34) ) if strpos(`var',"regexm")
				replace `var' = ustrregexra(`var', "\)", char(34)+"\)" ) if strpos(`var',"regexm")
				replace `var' = ustrregexra(`var', char(34)+"\),", "\)," ) if strpos(`var',"regexm")
				
			}

			* add relevance to if condition
			replace if_condition = if_condition + " & (" + relevance + ")" if !missing(if_condition)
			replace if_condition = relevance if missing(if_condition)
				
			* generate assertion. Assert for non-missing in all. Manual edits will be needed for addional
			* assertions required
			gen assertion = name_log + " == ."  if regexm(type, "integer|select_one")
			replace assertion = "!missing(" + name_log + ")" ///
												if missing(assertion) & ///
												!inlist(type, "begin group", "end group", "begin repeat", "end repeat")
													
			* export variables to skip sheet. 
		
			export excel name_log `label' assertion if_condition using "`outfile'", sheet("6. logic") sheetmodify cell(A2)
			noi disp "... 6. logic complete"
		}

		* 8. constraints
		use `_survey', clear
		keep type name `label' constraint		
			* keep only fields with contraints
			keep if !missing(constraint) & inlist(type, "integer", "decimal")
			if `=_N' > 0 {
				split constraint, parse("and" "or") gen(constraint_)
				gen hardmin = ""
				gen hardmax = ""
				gen softmin = ""
				gen softmax = ""	
				
					foreach var of varlist constraint_* {
						replace `var' = ""  if strpos(`var',"$")
						replace `var' = ""  if !strpos(`var',"<") & !strpos(`var',">")
						*hardmin
						replace hardmin = regexs(3)  if regexm(`var',"(.)+(>=)+([0-9]+\.?[0-9]*)") 
						replace hardmin = string(real(regexs(3)) + 1)  if regexm(`var',"(.)+(>)+([0-9]+\.?[0-9]*)") & type=="integer"
						replace hardmin = string(real(regexs(3)) + .01)  if regexm(`var',"(.)+(>)+([0-9]+\.?[0-9]*)") & type=="decimal"
						*hardmax
						replace hardmax = regexs(3)  if regexm(`var',"(.)+(<=)+([0-9]+\.?[0-9]*)") 
						replace hardmax = string(real(regexs(3)) - 1)  if regexm(`var',"(.)+(<)+([0-9]+\.?[0-9]*)") & type=="integer"
						replace hardmax = string(real(regexs(3)) - .01)  if regexm(`var',"(.)+(<)+([0-9]+\.?[0-9]*)") & type=="decimal"
					
						*softmin
						replace softmin = string(ceil(real(hardmin) + real(hardmin)* (`softmin'/100))) if type=="integer"
						replace softmin = string(real(hardmin) + real(hardmin)* (`softmin'/100)) if type=="decimal"
						
						*softmax
						replace softmax = string(floor(real(hardmax) - real(hardmax)* (`softmax'/100))) if type=="integer"
						replace softmax = string(real(hardmax) - real(hardmax)* (`softmax'/100)) if type=="decimal"
			
					}
				replace softmin = "" if softmin == "."
				replace softmax = "" if softmax == "."
				drop if mi(hardmin) & mi(hardmax)

				* export variable names, `label', constraints to first column A
			
				export excel name `label' constraint hardmin softmin softmax hardmax using "`outfile'", ///
					sheet("8. constraints") sheetmodify cell(A2)
				noi disp "... 8. constraint complete"
			}
			
		* 9. specify
		use `_survey', clear
		keep type name relevance		
			keep if regexm(relevance, "`osp'") & !regexm(type, "begin") & type == "text"
			if `=_N' > 0 {
				* rename name child and keep only needed variables
				ren (name) (child)
				keep child relevance
				* generate parent
				replace relevance = trim(itrim(relevance))
				gen parent = substr(relevance, strpos(relevance, "$") + 2, strpos(relevance, "}") - strpos(relevance, "$") - 2)

				* Export child and parent variables
				export excel child parent using "`outfile'", sheet("9. specify") sheetmodify cell(A2)
				noi disp "... 9. specify complete"
			}

		*10. dates 
		use `_survey', clear

		keep if inlist(type, "start", "end")
		if `=_N' > 0 {
			forval x=1/`=_N' {
				if type[`x']=="start" loc startvar = name[`x'] 
				if type[`x']=="end" loc endvar = name[`x'] 	
			}

			clear
			set obs 1
			gen start = "`startvar'"			
			gen end = "`endvar'"	
			gen surveystart = "`surveystart'"
			* Export date variables
			export excel start end surveystart using "`outfile'", sheet("10. dates") sheetmodify cell(A2)
			
			noi disp "... 10. dates complete"
		}	

		* 11. outliers
		use `_survey', clear
		keep type `label' name appearance		 
			* keep only integer and decimal fields
			keep if (type == "decimal" | type == "integer") & appearance != "label"
			
			* Export variable names and multiplier
			if `=_N' > 0 {
				if "`multiplier'" != "" {
					loc multiplier = subinstr("`multiplier'", " ", "", .)
					gettoken val sd : multiplier, parse(",")
					if `"`=lower(subinstr("`sd'",",","",.))'"' == "sd" {
						loc sd  `"`=lower(subinstr("`sd'",",","",.))'"' 	
					}
					else {
						loc sd = ""
					}									
					gen multiplier = `val'	
				}
				else {
					gen multiplier = 3
					loc sd = "sd"
				}
				
				export excel name `label' multiplier using "`outfile'", sheet("11. outliers") sheetmodify cell(A2)
				noi disp "... 11. outliers complete"
			}

		* 13. text_audit
		use `_survey', clear
		keep type  name appearance 		
			* keep group names, if not field-list as appearance
			keep if type == "begin group" & !regex(appearance, "field-list")
			* Export variable names
			if `=_N' > 0 {
				export excel name using "`outfile'", sheet("13. text audit") sheetmodify cell(A2)
				noi disp "... 13. text audit complete"
			}
		
			
		* enumdb
		* Import choices
		use `_choices', clear
			* keep only list_name and value fields
			keep list_name value
			* get names of list_names with rf | dk
			levelsof list_name if value == "`refusal'" | value == "`dontknow'", loc (dkrf_opts)
		* Import survey
		use `_survey', clear
		keep type name 
			* Drop group names
			drop if regexm(type, "group")
			* Loop through and mark variables with dk ref opts
			gen dkref_var = 0
			foreach opt in `dkrf_opts' {
				replace dkref_var = 1 if regexm(type, "`opt'")
			}
			
			* keep only dkref vars and text fields
			keep if dkref_var == 1 | type == "text" 

			* Export dk and refusal vars
			export excel name using "`outfile'", sheet("enumdb") sheetmodify cell(A2)

		* export missing rate
		use `_survey', clear
		gen include_grp = 0
		replace relevance = subinstr(relevance, "$", "", .) if !missing(relevance)
		levelsof _sn if !missing(relevance) & !regexm(type, "begin group|begin repeat"), ///
			loc (groups) clean
		foreach group in `groups' {
			loc start 	= _sn[`group']
			loc end 	= _sn[`group']
			replace include_grp = 1 in `start'/`end'
		}
		
		keep if include_grp | (!missing(relevance) & !regexm(type, "note|begin group|end group|end repeat|begin repeat"))
		* Export missing var rate and refusal vars
			cap export excel name using "`outfile'", sheet("enumdb") sheetmodify cell(B2)

		* export other specify
		use `_survey', clear
		cap export excel name_log using "`outfile'" if regexm(relevance, "`osp'") & !regexm(type, "note|begin group|end group|end repeat|begin repeat"), sheet("enumdb") sheetmodify cell(D2)

		* Export duration
		use `_survey', clear
		keep type name calculation
		keep if calculation == "duration()" 

		* Export duration
		cap export excel name using "`outfile'", sheet("enumdb") sheetmodify cell(C2)

		* Export stats variable
		use `_survey', clear
		keep type name

		* Keep all integer and decimal fields
		keep if inlist(type, "integer", "decimal") 

		* Export stats variables
		cap export excel name using "`outfile'", sheet("enumdb") sheetmodify cell(E2)

		* Export stats variables
		clear
		set obs 1
		g sub = "submissiondate" in 1

		export excel sub using "`outfile'", sheet("enumdb") sheetmodify cell(G2)
		noi disp "... enumdb complete"

		* research oneway
		if "`r1'"!="" {
			use `_survey', clear
			foreach var of local r1 {
				count if newname == "`var'"
				if r(N)==0 {
					noi di as err "`var' does not exist"
					exit 111	
				}
				
			}
			loc r1 = stritrim("`r1'")
			loc r1 = ustrregexra("`r1'", " ", "|")
			gen vartype="contn" if inlist(type, "integer", "decimal", "calculate")
			replace vartype="cat" if regex(type, "select_")==1 
			export excel name `label' vartype if regex(newname, "^(`r1')$")==1  using "`outfile'", 							///
			sheet("research oneway") sheetmodify cell(A2)
			noi disp "... research oneway complete"
		}

		if "`r1'"=="" {
			use `_survey', clear
			drop if appearance == "label"
			keep if type == "integer" | type == "decimal" | regexm(type, "select_one") 
			if `=_N' > 0 {
				
				gen category = cond(type == "integer" | type == "decimal", "cont", cond(regexm(type, "yesno")|regexm(type, "yn"), "bin", "cat"))

				*Common things you don't want in the research tab
				drop if regexm(type, "name") | regexm(type, "id") | regexm(type, "team")

				export excel name `label' category  using "`outfile'", 							///
				sheet("research oneway") sheetmodify cell(A2)

			}
			noi disp "... research oneway complete"
		}

		* research twoway
		if "`r2'"!="" {
			use `_survey', clear
			gettoken arg rest : r2, parse(",")
			local varby   : word 2 of `rest'
			local allvarr = "`arg'" + " `varby'"
			foreach var of local allvarr {
				count if newname == "`var'"
				if r(N)==0 {
					noi di as err "`var' does not exist"
					exit 111	
				}
				
			}
			* By var
			gen varby = lower(stritrim("`varby'"))
			gen vartype="contn" if inlist(type, "integer", "decimal", "calculate")
			replace vartype="cat" if regex(type, "select_")==1 
			* Varlist
			loc arg = stritrim("`arg'")
			loc arg = ustrregexra("`arg'", " ", "|")
			export excel name `label' vartype varby if regex(newname, "^(`arg')$")==1  using "`outfile'", 							///
			sheet("research twoway") sheetmodify cell(A2)
			noi disp "... research twoway complete"
		
			
		}

		* Backcheck
		if "`backcheck'" != "" {
			import excel using "`backcheck'", sheet("survey") firstrow allstr clear
			drop if missing(type) | regexm(disabled, "[Yy][Es][Ss]") | type=="note"
			replace `label' = ustrregexra(`label', "<.*?>", " " ) if strpos(`label',"<")
			
			* Mark beginning and end of groups and repeats
			count if regexm(type, "group|repeat")

			gen grp_var 	= .
			gen rpt_grp_var = .

			gen begin_row 		= .
			gen begin_fieldname = ""
			gen end_row			= .
			gen end_fieldname 	= ""

			if `r(N)' > 0 {
				
				* generate _n to mark groups
				gen _sn = _n
				
				* get the name of all begin groups|repeat and check if the name if their pairs match
				levelsof _sn if (regexm(type, "^(begin)") & regexm(type, "group|repeat")), ///
					loc (_sns) clean
				
				count if (regexm(type, "^(begin)") & regexm(type, "group|repeat"))
				loc b_cnt `r(N)'
				count if (regexm(type, "^(end)") & regexm(type, "group|repeat"))
				loc e_cnt `r(N)'
				
				if `b_cnt' ~= `e_cnt' {
					di as err "Error in Backehck XLS form: There are `b_cnt' begin types and `e_cnt' end types"
					exit 198
				}
			
				foreach _sn in `_sns' {	

					if regexm(type[`_sn'], "group") loc gtype "grp"
					else loc gtype "rpt_grp"

					loc b 1
					loc e 0
					loc curr_sn `_sn'
					loc stop 0
					while `stop' == 0 {
						loc ++curr_sn 
						cap assert regexm(type, "^(end)") & regexm(type, "group|repeat") in `curr_sn'
						if !_rc {
							loc ++e
							if `b' == `e' {
								loc end `curr_sn'
								loc stop 1
							}
						}
						else {
							if "`gtype'" == "grp" replace grp_var = 1 in `curr_sn'
							if "`gtype'" == "rpt_grp" replace rpt_grp_var = 1 in `curr_sn'
							cap assert regexm(type, "^(begin)") & regexm(type, "group|repeat") in `curr_sn'
							if !_rc loc ++b
						}
					}

					replace begin_row 		= 	_sn[`_sn']		in `_sn'
					replace begin_fieldname =	name[`_sn']		in `_sn'
					replace end_row 		= 	_sn[`end']		in `_sn'
					replace end_fieldname 	=	name[`end']		in `_sn'
				}

				replace grp_var 	= 0 if missing(grp_var)
				replace rpt_grp_var = 0 if missing(rpt_grp_var)

				replace name = subinstr(name, "*", "", .) if (regexm(type, "^(begin)") & regexm(type, "group|repeat")) in `curr_sn'
			}
			
			* Check form for repeat groups and mark all repeat group variables
				
			* drop all repeat variables if long option is used
			if "`long'" ~= "" {
				drop if rpt_grp_var
				replace _sn = _n
			}
				
			* include a wild card in repeat var names if option excluderepeats is not used
			if  "`wide'" ~= "" {
				replace name = name + "*" if rpt_grp_var
			}

			keep if (inlist(type, "text", "integer", "decimal", "date", "datetime") | regex(type, "calculate")==1| ///
					regex(type, "select_")==1) & calculation!="duration()"

			export excel name `label'  using "`outfile'", 							///
			sheet("backchecks") sheetmodify cell(A2)
			noi disp "... backchecks complete"
			
		}

		u `setup', clear
		replace data = "$surveyid" in 23 // unique ID

		export excel data using "`outfile'", 							///
		sheet("0. setup") sheetmodify cell(B4)

		* Export SD 
		clear 
		set obs 1
		g data = "`sd'" in 1 // specify sd or iqr
		export excel data using "`outfile'", 							///
		sheet("0. setup") sheetmodify cell(B55)
		
		noi disp "... 0. setup complete", _n

		noi disp "Please remember to add and modify the input file before you run HFC." 	
		noi disp "    - Turn on and off the checks as appropriate" 
		noi disp "    - Add variables from repeat groups if you are using wide data having repeat groups" 
		noi disp "    - Add additional logic checks in the logic sheet"
		noi disp "    - Modify backchecks sheet to specify types of each variable and backcheck options", _n		
	} 

	noi display `"Your {browse "https://github.com/PovertyAction/high-frequency-checks":IPA HFC input} is saved here {browse "`outfile'":`outfile'}"'
end
