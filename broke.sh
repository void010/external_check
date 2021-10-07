#!/bin/bash


#####
####### linkchecker, secretfinder, gobuster
#####

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

############### HELP
Help()
{	
	echo ""
	echo -e "${YELLOW}Syntax: ./script url crawl_depth Thread_number "
	echo ""
	echo -e "url           - Target URL to crawl"
	echo -e "-h            - print this help message"
	echo -e "crawl depth   - Depth to crawl"
	echo -e "Thread number - Number of threads"
	return
}

while getopts ":h" option; do
	case $option in
		h) Help
			exit;;
	esac
done
###############

s_code=$(curl -L -s --head --request GET $1 -o /dev/null --write-out '%{http_code}\n' -m 15)

if [[ $s_code == 200 ]]; then 
   echo -e "${GREEN}$1 is accessible ${NC}\n"
elif [[ $s_code == 503 ]] || [[ $s_code == 500 ]]; then
	echo -e "${RED}Server error${NC}\n"
	exit 1
elif [[ $s_code == 403 ]]; then
	echo -e "${RED}Access Forbidden${NC}\n"
	exit 1
else
   echo -e "${RED}$1 is not accessible ${NC}\n"
   exit 1
fi

echo "Target is $1"
echo "Depth of crawl is $2"
echo "Threads used $3"
turl=$1
depth=$2
thread=$3

dir=$(echo $1 | sed 's|/||g')__$(date +"%d-%m-%Y") 
target=$(curl -Ls -w %{url_effective} -o /dev/null $turl -m 15)
echo -e "\n${GREEN}URL Directed to : $target${NC}"

################ Main crawling
echo -e "\n${GREEN}Crawling the Application at given depth${NC}"
mkdir $(pwd)/$dir
$(pwd)/tools/linkchecker/linkchecker $target -r $depth -t $thread -F text/$(pwd)/$dir/output.txt --check-extern --no-warning -v #>>/dev/null 2>&1
sleep 3

################ DNS Resolution Failing External URLs
echo -e "\n${GREEN}Trying to resolve DNS entries${NC}"
cat $(pwd)/$dir/output.txt | grep -w "Parent URL\|Real URL\|Result" | awk ' {print;} NR % 3 == 0 { print ""; }' | grep -v -w "SSLError" | tee $(pwd)/$dir/sorted.txt >>/dev/null 2>&1
cat $(pwd)/$dir/sorted.txt | grep -w "ConnectionError: HTTPSConnectionPool\|ConnectionError: HTTPConnectionPool" -B3 | tee $(pwd)/$dir/error.txt >>/dev/null 2>&1
cat $(pwd)/$dir/error.txt | sed '/ConnectionError/ c\Result     Need Manual check' | tee $(pwd)/$dir/dns_test.txt >>/dev/null 2>&1
cat $(pwd)/$dir/dns_test.txt | grep -v -f "$(pwd)/tools/extern_dom.txt" |grep -v "@" | tee $(pwd)/$dir/DNS.txt >>/dev/null 2>&1
cat $(pwd)/$dir/sorted.txt | grep -w "Error: 404 Not Found" -B3 | tee $(pwd)/$dir/404.txt >>/dev/null 2>&1
cat $(pwd)/$dir/sorted.txt | grep -w "Error: 410" -B3 | tee $(pwd)/$dir/410.txt >>/dev/null 2>&1
cat $(pwd)/$dir/sorted.txt | grep -w "Error: 403" -B3 | tee $(pwd)/$dir/403.txt >>/dev/null 2>&1
sleep 2
rm $(pwd)/$dir/error.txt >>/dev/null 2>&1
rm $(pwd)/$dir/dns_test.txt >>/dev/null 2>&1

############### Finding Fuzzable internal URLs
echo -e "\n${GREEN}Finding Fuzzable URLs${NC}"
cat $(pwd)/$dir/sorted.txt |grep "Real URL"|awk '{print $3}' | grep "=" | tee $(pwd)/$dir/fuzz_test.txt >>/dev/null 2>&1
grep -v -f $(pwd)/tools/extern_dom.txt $(pwd)/$dir/fuzz_test.txt | tee $(pwd)/$dir/fuzzable.txt >>/dev/null 2>&1
cat $(pwd)/$dir/fuzzable.txt | grep -i "$(echo $target | awk -F[/:] '{print $4}')" | tee $(pwd)/$dir/Fuzz.txt >>/dev/null 2>&1
rm $(pwd)/$dir/fuzz_test.txt >>/dev/null 2>&1
rm $(pwd)/$dir/fuzzable.txt

############### Finding senstive info in internal JS files (NEED TO ADD SECRET FINDER)
cat $(pwd)/$dir/sorted.txt | grep ".*\.js$" | awk '{print$3}'| tee $(pwd)/$dir/internal_jsfile.txt

############### Finding Technology used

############### Finding Mixed Content in External domain
echo -e "\n${GREEN}Finding Mixed content${NC}"
cat $(pwd)/$dir/sorted.txt|grep -w "Real URL"| grep -w "http"| grep -v -f "$(pwd)/tools/extern_dom.txt" | grep -v "@" |awk '{print $3}' | tee $(pwd)/$dir/mixed.txt
while read url; do
	a=$(curl -L -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.183 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' -H 'accept-language: en-US,en;q=0.9' -s -vv $url 2>&1 | grep -i strict-transport)
	if [ -z "$a" ]
	then
		echo $url | tr -d '\n' >> $(pwd)/$dir/Mixed_content.txt
		echo -e '\t:' | tr -d '\n' >> $(pwd)/$dir/Mixed_content.txt
		echo -e "HSTS NOT present" >> $(pwd)/$dir/Mixed_content.txt
	else
		echo $url | tr -d '\n' >> /dev/null 2>&1
	fi
done<$(pwd)/$dir/mixed.txt
rm $(pwd)/$dir/mixed.txt

################ HTML Template
echo -e "\n${GREEN}Generating report${NC}"


echo "<!DOCTYPE html>">>$(pwd)/$dir/report.html
echo "<html>">>$(pwd)/$dir/report.html
echo "<head>">>$(pwd)/$dir/report.html
echo "<meta name='viewport' content='width=device-width, initial-scale=1'>">>$(pwd)/$dir/report.html
echo "<style>">>$(pwd)/$dir/report.html
echo ".collapsible {">>$(pwd)/$dir/report.html
echo "  background-color: #777;">>$(pwd)/$dir/report.html
echo "  color: white;">>$(pwd)/$dir/report.html
echo "  cursor: pointer;">>$(pwd)/$dir/report.html
echo "  padding: 18px;">>$(pwd)/$dir/report.html
echo "  width: 100%;">>$(pwd)/$dir/report.html
echo "  border: none;">>$(pwd)/$dir/report.html
echo "  text-align: left;">>$(pwd)/$dir/report.html
echo "  outline: none;">>$(pwd)/$dir/report.html
echo "  font-size: 15px;">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo ".active, .collapsible:hover {">>$(pwd)/$dir/report.html
echo "  background-color: #555;">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo ".collapsible:after {">>$(pwd)/$dir/report.html
echo "  content: '\002B';">>$(pwd)/$dir/report.html
echo "  color: white;">>$(pwd)/$dir/report.html
echo "  font-weight: bold;">>$(pwd)/$dir/report.html
echo "  float: right;">>$(pwd)/$dir/report.html
echo "  margin-left: 5px;">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo ".active:after {">>$(pwd)/$dir/report.html
echo "  content: '\2212';">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo ".content {">>$(pwd)/$dir/report.html
echo "  padding: 0 18px;">>$(pwd)/$dir/report.html
echo "  max-height: 0;">>$(pwd)/$dir/report.html
echo "  overflow: hidden;">>$(pwd)/$dir/report.html
echo "  transition: max-height 0.2s ease-out;">>$(pwd)/$dir/report.html
echo "  background-color: #f1f1f1;">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "</style>">>$(pwd)/$dir/report.html
echo "</head>">>$(pwd)/$dir/report.html
echo "<body>">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html

### Add news Fields to the report Below

echo "<h2><u>Report for $turl</u></h2>">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo "<h6>Scanned on $(date)</h6>">>$(pwd)/$dir/report.html
echo "<button class='collapsible'>Domains with DNS issues</button>">>$(pwd)/$dir/report.html
echo "<div class='content'>">>$(pwd)/$dir/report.html
echo "  <p>Total number - $(cat $(pwd)/$dir/DNS.txt | grep "Real URL" | wc -l)<br>Click <a href="$(pwd)/$dir/DNS.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "</div>">>$(pwd)/$dir/report.html
echo "<button class='collapsible'>Internal JS files Analyzed</button>">>$(pwd)/$dir/report.html
echo "<div class='content'>">>$(pwd)/$dir/report.html
echo "  <p>Total number - $(cat $(pwd)/$dir/internal_jsfile.txt | wc -l)<br>Click <a href="$(pwd)/$dir/internal_jsfile.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "</div>">>$(pwd)/$dir/report.html
echo "<button class='collapsible'>Broken Links (404 ,410 & 403)</button>">>$(pwd)/$dir/report.html
echo "<div class='content'>">>$(pwd)/$dir/report.html
echo "  <p>Total number 404 - $(cat $(pwd)/$dir/404.txt | grep "Real URL" | wc -l)<br>Click <a href="$(pwd)/$dir/404.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "  <p>Total number 410 - $(cat $(pwd)/$dir/410.txt | grep "Real URL" | wc -l)<br>Click <a href="$(pwd)/$dir/410.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "  <p>Total number 403 - $(cat $(pwd)/$dir/403.txt | grep "Real URL" | wc -l)<br>Click <a href="$(pwd)/$dir/403.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "</div>">>$(pwd)/$dir/report.html
echo "<button class='collapsible'>Fuzzable URLs</button>">>$(pwd)/$dir/report.html
echo "<div class='content'>">>$(pwd)/$dir/report.html
echo "  <p>Total number - $(cat $(pwd)/$dir/Fuzz.txt| wc -l)<br>Click <a href="$(pwd)/$dir/Fuzz.txt" target="_blank">here </a>to view complete list.</p>">>$(pwd)/$dir/report.html
echo "</div>">>$(pwd)/$dir/report.html




echo "">>$(pwd)/$dir/report.html
echo "<script>">>$(pwd)/$dir/report.html
echo "var coll = document.getElementsByClassName('collapsible');">>$(pwd)/$dir/report.html
echo "var i;">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo "for (i = 0; i < coll.length; i++) {">>$(pwd)/$dir/report.html
echo "  coll[i].addEventListener('click', function() {">>$(pwd)/$dir/report.html
echo "    this.classList.toggle('active');">>$(pwd)/$dir/report.html
echo "    var content = this.nextElementSibling;">>$(pwd)/$dir/report.html
echo "    if (content.style.maxHeight){">>$(pwd)/$dir/report.html
echo "      content.style.maxHeight = null;">>$(pwd)/$dir/report.html
echo "    } else {">>$(pwd)/$dir/report.html
echo "      content.style.maxHeight = content.scrollHeight + 'px';">>$(pwd)/$dir/report.html
echo "    } ">>$(pwd)/$dir/report.html
echo "  });">>$(pwd)/$dir/report.html
echo "}">>$(pwd)/$dir/report.html
echo "</script>">>$(pwd)/$dir/report.html
echo "">>$(pwd)/$dir/report.html
echo "</body>">>$(pwd)/$dir/report.html
echo "</html>">>$(pwd)/$dir/report.html

################

echo -e "\n${GREEN}Completed !!! ${NC}"
exit 0