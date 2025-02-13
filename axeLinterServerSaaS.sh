#!/bin/bash
Files=`find . -type f -print` 
ApiKey=add-your-axe-linter-api-key-here
outFile="axe-linter-reportSaaS.json"
totalFilesCount=`find . -type f -printf '.' | wc -c`
counter=0
rm $outFile
touch $outFile
echo '{"issues": []}' >$outFile
echo "Running updated axe Linter Server SaaS Bash Script (This may take a few moments)..."
for File in $Files; do
	if [[ $File == *.html ]] || [[ $File == *.js ]] || [[ $File == *.jsx ]]|| [[ $File == *.tsx ]]|| [[ $File == *.vue ]]|| [[ $File == *.htm ]]|| [[ $File == *.md ]]|| [[ $File == *.markdown ]];	    
	then
        FileContents="$(cat "$File")"
		RequestBody=$(
			jq \
			--null-input \
			--arg Source "$FileContents" \
			--arg Filename "$File" \
			'{ "source": $Source, "filename": $Filename }'
		)

		Response=$(
			curl \
			--silent \
			--request POST \
			--url https://axe-linter.deque.com/lint-source \
			--header "content-type: application/json" \
			--header "authorization: $ApiKey" \
			--data "${RequestBody}"
		)

        ErrorCount=$(echo "$Response" | jq '.report.errors | length')
        if [ "$ErrorCount" != "0" ]; then
            # There are detected issues. Add to sonarqube GIIF file:
            echo "$Response" |
            jq -r --compact-output '.report.errors[] | .ruleId + " " + .linterType + " " + .helpURL + " " + (.lineNumber|tostring) + " " + (.column|tostring) + " " + (.endColumn|tostring) + " " + .description' |
            while read -r RuleId LinterType HelpURL Line Column EndColumn Description; do
            myRuleId="${RuleId} (${HelpURL})"
            severity="MAJOR"
            type="BUG"
            Column=$((Column-1))
            EndColumn=$((EndColumn-1))
            engineId="axe-linter-${LinterType}"
            filePath=`realpath ${File}`
            myResult=$(jq --arg myEngine "$engineId" --arg ruleId "$myRuleId" --arg severity "$severity" --arg myType "$type" --arg filePath "$filePath" --arg message "$Description" --arg startLine "$Line" --arg endLine "$Line" --arg startColumn "$Column" --arg endColumn "$EndColumn" '.issues[.issues| length] |= . + {("engineId"):$myEngine, ("ruleId"):$ruleId, ("severity"):$severity, ("type"):$myType, ("primaryLocation"):{("filePath"):$filePath, ("message"):$message, ("textRange"):{("startLine"):($startLine)|tonumber, ("endLine"):($endLine)|tonumber, ("startColumn"):($startColumn)|tonumber, ("endColumn"):($endColumn)|tonumber}}}' $outFile)
            echo "${myResult}" > $outFile
            done
        fi
        
    fi
    echo -ne 'Linting file '$counter'/'$totalFilesCount '\r'
    counter=$((counter+1))
done
