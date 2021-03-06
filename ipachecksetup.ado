*! Version 1.0.1 Ishmail Azindoo Baako and Mehrab Ali 20Nov2020
*! Version 1.0.0 Ishmail Azindoo Baako and Mehrab Ali 19Sep2020
* Originally created by Ishmail Azindoo Baako (IPA) 24feb2018


version 	12.0
cap program drop ipachecksetup
program define  ipachecksetup
	#d;
	syntax	using/, [template(string)] outfile(string) prefix(string) [outfolder(string)]
					[osp(real -666) REFusal(real -888) DONTKnow(real -999) na(real -222)
					consent(string) id(string) incomplete(string) surveystart(string)
					MULtiplier(string) r1(string) r2(string) BACKcheck(string)
					replace long wide label(string) enumid(string) teamid(string) 
					bcid(string) bcteamid(string) survey(string) media(string) SOFTMIn(real 10) SOFTMAx(real 10)] 
		;
	#d cr

 	qui {
 		tempfile ipachecksetupdata
 		save `ipachecksetupdata', emptyok

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
		gen grp_rel			= ""

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
						loc grouprel = "(" + relevance[`_sn'] + ")"

						if "`gtype'" == "grp" &  !mi(relevance[`_sn'])  /// 
								replace relevance = relevance + " and ("+ relevance[`_sn'] + ")" if !regexm(relevance, "`grouprel'") ///
													in `curr_sn' 
						if "`gtype'" == "grp" replace relevance = regexr(relevance, "^ and ", "")
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
			
			levelsof name_log if rpt_grp_var, local(rpt_vars)

			foreach var of local rpt_vars {
				local bvar = subinstr("`var'", "_1", "", .)
				replace relevance = subinstr(relevance, "`bvar'", "`var'", .)
			}

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
		loc outfile = subinstr("`outfile'", "\", "/", .)
		if "`outfolder'" == "" {
			loc outfolder = reverse(substr(reverse("`outfile'"),strpos(reverse("`outfile'"), "/"), . ))	
		}
		
		if "`template'"!="" {
			copy "`template'" "`outfile'", `replace'
		}
		else {
			cap confirm file "`outfile'"
			if "`replace'" == "" & !_rc {
				noi di as err "file `outfile' already exists"
				exit 602
			}
			else{
				copy "`git_hfc'/`branch'/xlsx/hfc_inputs.xlsm" "`outfile'", `replace'
			}
			
		}
		
		*00. setup
		clear
		set obs 40
		loc survey = subinstr("`survey'", "\", "/", .)
		loc media = subinstr("`media'", "\", "/", .)
		gen		data = "`survey'" 			in 1  // Dataset
		replace data = "`backcheck'" 		in 2 // BC dataset
		replace data = "`media'" 			in 4 // Media folder

		replace data = "`outfile'" 			in 7 // HFC & BC input file name
		loc outfile_dup = "`outfolder'`prefix'" + "_duplicates.xlsx"
		loc outfile_hfc = "`outfolder'`prefix'" + "_hfc_output.xlsx"
		loc outfile_enum = "`outfolder'`prefix'" + "_enumdb.xlsx"
		loc outfile_text = "`outfolder'`prefix'" + "_text.xlsx"
		loc outfile_r = "`outfolder'`prefix'" + "_research.xlsx"

		replace data = "`outfile_hfc'" 		in 12 //  file name
		replace data = "`outfile_enum'" 	in 13 // enumdb file name
		replace data = "`outfile_text'" 	in 14 // text audit file name
		replace data = "`outfile_dup'" 		in 16 // duplicate file name
		if "`backcheck'"!="" {
			loc outfile_bc = "`outfolder'/`prefix'" + "_bc.xlsx"
			replace data = "`outfile_bc'" 	in 17 // backcheck file name
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
		replace data = "`na'" 				in 35 // missing (.n)


		tempfile setup
		save `setup'
		
		*01. incomplete
		if "`incomplete'"!="" {
			clear
				g complete_value = ""
				g name = ""
				
				
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
				g complete_percent = 100
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
			clear
			gen name = ""

			loc i=1
			foreach varname of local id {
				set obs `i'
				replace name = "`varname'" in `i'
				loc ++i
			}

			drop if mi(name)
			duplicates drop name, force
			tempfile sid
			save `sid'

			use `_survey', clear
			merge m:1 name using `sid', gen(mergeids)

			levelsof name if mergeids==2, local(idlist) clean
			count if mergeids==2	
				if r(N)>0 {
					noi di as err "Variable(s) `idlist' does not exist, but added in setup sheet."
					noi di as result "", _n
					sleep 200
				}		

 
			keep if mergeids!=1 

			export excel name `label' using "`outfile'", 							///
			sheet("2. duplicates") sheetmodify cell(A2)
			noi disp "... 2. duplicates complete"
			
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
		keep if regexm(required, "[Yy][Ee][Ss]") | inlist(name, "starttime", "endtime", "duration") | (!mi(required) & lower(required)!="no")
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
				if `=_N' > 0 {
				export excel name `label' constraint hardmin softmin softmax hardmax using "`outfile'", ///
					sheet("8. constraints") sheetmodify cell(A2)
				noi disp "... 8. constraint complete"
			 	}
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
			gen surveystart =  `"`=date("`surveystart'", "MDY")'"' 
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
				mata: multiplier_format("`outfile'", "11. outliers", `=_N+1')
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

		* Export excludevars variables
		use `_survey', clear
		keep if !regexm(type, "select|calculate|group|repeat|note|integer|decimal|date|geo|text|caseid")
		set obs `=_N+3'
		replace name = "formdef_version" in `=_N-2'
		replace name = "submissiondate" in `=_N-1'
		replace name = "key" in `=_N'
		cap export excel name using "`outfile'", sheet("enumdb") sheetmodify cell(F2)

		* research oneway
		if "`r1'"!="" {
			use `_survey', clear
			foreach var of local r1 {
				count if name == "`var'"
				if r(N)==0 {
					noi di as err "`var' does not exist"
					exit 111	
				}
				
			}
			loc r1 = stritrim("`r1'")
			loc r1 = ustrregexra("`r1'", " ", "|")
			gen vartype="contn" if inlist(type, "integer", "decimal", "calculate")
			replace vartype="cat" if regex(type, "select_")==1 
			export excel name_log `label' vartype if regex(newname, "^(`r1')$")==1  using "`outfile'", 							///
			sheet("research oneway") sheetmodify cell(A2)
			noi disp "... research oneway complete"
		}

		if "`r1'"=="" {
			use `_survey', clear
			drop if appearance == "label"
			keep if type == "integer" | type == "decimal" | regexm(type, "select_one") 
			if `=_N' > 0 {
				
				gen category = cond(type == "integer" | type == "decimal", "contn", cond(regexm(type, "yesno")|regexm(type, "yn"), "bin", "cat"))

				*Common things you don't want in the research tab
				drop if regexm(type, "name") | regexm(type, "id") | regexm(type, "team")

				export excel name_log `label' category  using "`outfile'", 							///
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
			export excel name_log `label' vartype varby if regex(newname, "^(`arg')$")==1  using "`outfile'", 							///
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
		replace data = "`id'" in 23 // unique ID

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
		noi disp "    1) Activate and deactivate the checks as appropriate in 0. setup sheet" 
		noi disp "    2) Locate replacement file and sheet name" 
		noi disp "    3) Setup follow up sheet if needed"
		noi disp "    4) Add variables from repeat groups if you are using wide data having repeat groups" 
		noi disp "    5) Add logic checks in the logic sheet"
		noi disp "    6) Modify backchecks sheet to specify types of each variable and backcheck options", _n		
	} 

	noi display `"Your {browse "https://github.com/PovertyAction/high-frequency-checks":IPA HFC input} is saved here {browse "`outfile'":`outfile'}"'

	u `ipachecksetupdata', clear
	

end


mata:
	mata clear
	void multiplier_format(string scalar filename, string scalar sheet, real scalar nrow)
	{
		class xl scalar b
		b = xl()
		b.load_book(filename)
		b.set_sheet(sheet)
		
		rows = (2, nrow)
		cols = (3, 3)

		b.set_number_format(rows,cols,"number_d2")
		
	}
		
end

