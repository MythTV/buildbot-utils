#!/usr/bin/python
from suds.client import Client
from suds.wsse import *
from operator import attrgetter
from datetime import datetime
#from datetime import timedelta
import sys

output_file = open(sys.argv[1], 'w')

WS_DEFECT_URL = "http://scan5.coverity.com:8080/ws/v7/defectservice?wsdl"
WS_CONFIG_URL = "http://scan5.coverity.com:8080/ws/v7/configurationservice?wsdl"
WS_USER = "buildbot@mythtv.org"
WS_PASS = "34*HkF&9"
PROJNAME = "MythTV"
STREAM = "MythTV"

defect_client = Client(WS_DEFECT_URL)
config_client = Client(WS_CONFIG_URL)
security = Security()
token = UsernameToken(WS_USER, WS_PASS)
security.tokens.append(token)
defect_client.set_options(wsse=security)
config_client.set_options(wsse=security)

projectID = defect_client.factory.create("projectIdDataObj")
projectID.name = PROJNAME

"""

#Unused since the object doesn't contain the information we want atm

# Build a filter for getTrendRecordsForProject().
# We want to get the stats for the most recent build, this means
# grabbing results for all builds in the last 14 days and using the latest
PTfilterSpec = defect_client.factory.create("projectTrendRecordFilterSpecDataObj")
PTfilterSpec.startDate = (datetime.now() - timedelta(days=14)).isoformat()
PTfilterSpec.endDate = datetime.now().isoformat()

# Query the build history for the projectCIDS
projectHistory = defect_client.service.getTrendRecordsForProject(projectID, PTfilterSpec)
"""

# Build a filter for getCIDsForProject().
# We want only defects which haven't be fixed, ignored or
# flagged as false positives. This filter is used with getCIDSForProject
MDfilterSpec = defect_client.factory.create("mergedDefectFilterSpecDataObj")
MDfilterSpec.classificationNameList = ["Bug", "Pending", "Unclassified"]
MDfilterSpec.actionNameList = ["Undecided", "Fix Required"]
MDfilterSpec.statusNameList = ["New", "Triaged"]

# Coverity doesn't allow us to simply request details for all defects, instead
# we have to specify the coverity ID for every defect we want. So first we
# need to fetch those IDs. We use the filter created above to only return the
# IDs we need.
projectCIDS = defect_client.service.getCIDsForProject(projectID, MDfilterSpec)

# Coverity limits the number of defects we can lookup at a time, that limit
# isn't stated in their documentation but is around, or exactly, 50
PAGE_SIZE = 50;

# This is the total number of _filtered_ defects.
total_defects = len(projectCIDS);

# Calculate the total number of pages we want to request
pages = ((total_defects + (PAGE_SIZE - 1)) / PAGE_SIZE);

# Print out the above information to stdout for the user
print str(total_defects) + " Total Results"
print "Fetching in " + str(pages) + " pages of " + str(PAGE_SIZE)

# Build a filter for getStreamDefects(). We don't want their history, but we
# do want the 'instance' information which includes the line number, file path
# and an actual description of the problem
SDfilterSpec = defect_client.factory.create("streamDefectFilterSpecDataObj")
SDfilterSpec.includeHistory = False
SDfilterSpec.includeDefectInstances = True

streamIdList = defect_client.factory.create("streamIdDataObj")
streamIdList.name = STREAM

SDfilterSpec.streamIdList = [streamIdList]
covdefects = []
page = 0
start = 0
while (page < pages):
    start = page * PAGE_SIZE;
    stop = min(start + PAGE_SIZE, total_defects)
    # Print out progress
    print "Fetching page " + str(page+1) + " (" + str(start) + "-" + str(stop) + ")"
    pageCIDs = projectCIDS[start:stop]
    covdefects += defect_client.service.getStreamDefects(pageCIDs, [SDfilterSpec])
    page = page + 1;

# Keep the user informed
print "Finishing fetching"

# Print the page header
HEADER = """
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-GB">
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<meta http-equiv="content-language" content="en-GB" />
<script src="sorttable.js" type="text/javascript"></script>
<script type="text/javascript">
//<![CDATA[
    function doFilter(filters)
    {
        var index = filters.selectedIndex;
        var filterType = filters.options[index].value;

        errorTable = document.getElementById('errors');
        rows = errorTable.rows;
        for (i = 1; i < rows.length; i++)
        {
            rows[i].style.visibility="collapse";

            switch (filterType)
            {
                case "high":
                    if (rows[i].className == "high")
                        rows[i].style.visibility="visible";
                    break;
                case "medium":
                    if (rows[i].className == "medium")
                        rows[i].style.visibility="visible";
                    break;
                case "low":
                    if (rows[i].className == "low")
                        rows[i].style.visibility="visible";
                    break;
                default:
                    rows[i].style.visibility="visible";
            }
        }
    }
//]]>
</script>
<style type="text/css">
body {background-color:#88a1bb;color:#000000;}
.sortable td {background-color:#DDDDDD;padding:3px;border:1px solid #000000}
th {color:#FFFFFF;background-color:#333333;padding:3px;}
select {color:#FFFFFF;background-color:#333333;font-size:1.1em;}
.idcolumn {text-align:center;vertical-align: middle;}
.typecolumn {text-align:center;font-weight:bold;color:#1a1a1a;text-transform:capitalize;padding:4px;}
.desccolumn {padding-left:8px;}
.high .typecolumn {background-color:#CC3333;}
.medium .typecolumn {background-color:#FF9900;}
.low .typecolumn {background-color:#99FF99;}
.paragraph {padding-bottom:5px;padding-top:5px;clear:left;}
.stats {float:right;margin-top:0px;border: 2px solid #666666;padding:5px;background-color:#DDDDDD;}
</style>
<title>MythTV Coverity Report</title>
</head>
<body>
"""
print >>output_file, HEADER

# Variables for the statistical information displayed
total = 0;
total_high = 0;
total_medium = 0;
total_low = 0;

class Defect:
    def __init__(self):
        self.order = 4
        self.impact = ""
        self.filename = ""
        self.description = ""
        self.line = 0
        self.typeShortDesc = ""
        self.typeLongDesc = ""
        self.coverityid = 0

print "Parsing result"

# Do a first pass over the error array, we need to create a int for each
# category to sort by.
# We also take the opportunity to get a total of each error category for
# display
#
# This cannot be replaced by a custom sorting function since we need the index
# for the dynamic javascript sorting too
simpleDefects = []
checkerCache = {}
for i, defect in enumerate(covdefects):
    if hasattr(defect, 'defectInstances'):
        newdefect = Defect()
        newdefect.order = 4;

        checkerProps = []
        checkerName = defect.checkerSubcategoryId.checkerName
        if (checkerName in checkerCache):
            checkerProps = checkerCache[checkerName]
        else:
            checkerObj = config_client.factory.create('checkerPropertyFilterSpecDataObj')
            checkerObj.checkerNameList = [defect.checkerSubcategoryId.checkerName]
            checkerObj.subcategoryList = [defect.checkerSubcategoryId.subcategory]
            checkerObj.domainList = [defect.checkerSubcategoryId.domain]

            checkerProps = config_client.service.getCheckerProperties(checkerObj);
            checkerCache[checkerName] = checkerProps

            if (len(checkerProps) == 0):
                print "Error: Unable to retrieve checker properties for " + checkerName;

        if (len(checkerProps) > 0):
            newdefect.impact = getattr(checkerProps[0],'impact').lower();
            newdefect.typeLongDesc = getattr(checkerProps[0],'subcategoryLongDescription');
            newdefect.typeShortDesc = getattr(checkerProps[0],'subcategoryShortDescription');

        if (newdefect.impact == "high"):
            newdefect.order = 1
            total_high = total_high + 1
        elif (newdefect.impact == "medium"):
            newdefect.order = 2
            total_medium = total_medium + 1
        elif (newdefect.impact == "low"):
            newdefect.order = 3
            total_low = total_low + 1
        else:
            newdefect.order = 4;

        newdefect.description = defect.defectInstances[0].events[-1].eventDescription
        newdefect.filename = defect.defectInstances[0].events[-1].fileId.filePathname
        newdefect.line = defect.defectInstances[0].events[-1].lineNumber

        newdefect.coverityid = defect.cid

        simpleDefects.append(newdefect)
        total = total + 1 # <sigh> python doesn't support post increment

del covdefects;

# Sort the array using the 'order' attributes we calculated above
simpleDefects.sort(key=attrgetter('order', 'filename', 'line'));

# Print Heading
PAGE_HEADING = """
<div class="stats">
    <div class="paragraph" style="font-size:1.3em;">There are {total} total results</div>
    <div class="paragraph" style="font-size:0.8em;">{total_high} high impact, {total_medium} medium impact and
        {total_low} low impact</div>
</div>
<div>
    <img src="https://www.mythtv.org/img/mythtv.png" alt="MythTV" style="float:left;padding-right:10px;"/>
    <h1 style="padding-top:15px;">Coverity Report</h1>
</div>
<div style="clear:both;">
    <br />
</div>
<table style="width:100%;">
    <tr>
        <td style="width:50%;vertical-align:bottom;">
            <div class="paragraph">Columns are sortable</div>
        </td>
        <td style="width:50%;text-align:right;">
            <div style="text-align:right;">
                <form action="index.html">
                    <fieldset style="width:auto;float:right;">
                        <legend><label for="filter">Show:</label></legend>
                        <select id="filter" onchange="doFilter(this);">
                            <option value="all">All</option>
                            <option value="high" style="color:#CC3333;">High</option>
                            <option value="medium" style="color:#FF9900;">Medium</option>
                            <option value="low" style="color:#99FF99;">Low</option>
                        </select>
                    </fieldset>
                </form>
            </div>
        </td>
    </tr>
</table>
""".format(total = total, total_high = total_high,
           total_medium = total_medium, total_low = total_low)
print >>output_file, PAGE_HEADING

# Print Error Table
TABLE_START = """
<table class="sortable" style="clear:both;" id="errors">
    <tr>
        <th>#</th>
        <th>Impact</th>
        <th>Description</th>
        <th>File</th>
    </tr>
"""
print >>output_file, TABLE_START

print "Writing into HTML document"

# We count from one here, this is not an iterator/index
defect_num = 1;
for i, defect in enumerate(simpleDefects):
    location = """<a target="_blank" href="https://code.mythtv.org/cgit/mythtv/tree{filename}#n{line}">{filename}:{line}</a><br />""".format(filename=defect.filename, line=str(defect.line))

    TABLE_ROW = """
    <tr class="{impact}">
        <td class="idcolumn" id="{defect_num}" title="{cov_id}">{defect_num}</td>
        <td class="typecolumn {impact}">
            <span style="display:none;">{order}</span> <!-- For sorting column -->
            <span>{impact}&nbsp;</span>
        </td>
        <td class="desccolumn" title="{typeLongDesc}">
            <span style="font-weight:bold;">{typeShortDesc}: </span><span>{description}</span>
            <span style="font-size:0.5em"> ({cov_id})</span>
        </td>
        <td class="locationcolumn">
            <span>{location}</span>
        </td>
    </tr>
    """.format(impact=defect.impact, order=defect.order, defect_num=defect_num, description=defect.description, location=location, cov_id=defect.coverityid, typeLongDesc=defect.typeLongDesc, typeShortDesc=defect.typeShortDesc)
    print >>output_file, TABLE_ROW

    defect_num = defect_num + 1 # Ditto

# Print error table close tag
TABLE_END = """
</table>
"""
print >>output_file, TABLE_END

# Format the current GMT date to a string to show when this html was generated
timestamp = datetime.utcnow().strftime("%e %b %Y %H:%M:%S")

# Print the page footer
FOOTER = """
<div style="text-align:center;">
    <br />
    Updated {timestamp} GMT
</div>
</body>
</html>
""".format(timestamp=timestamp)

print >>output_file, FOOTER

#close OF;
