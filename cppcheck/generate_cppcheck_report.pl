#!/usr/bin/perl

use warnings;
use strict;

# Yes, we need all of the following
use XML::Simple qw(:strict);
use POSIX;
use HTML::Entities;
# No longer core in the latest releases
use Switch;

# First argument to the script should be the xml file to process
# Second argument is the output file
my $file = $ARGV[0];
my $outfile = $ARGV[1];

open OF, ">", $outfile or die "Can't open output file $outfile: $!\n";

# Print the page header
print OF <<"HEADER";
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
                case "important":
                    if ((rows[i].className == "error") || (rows[i].className == "warning"))
                        rows[i].style.visibility="visible";
                    break;
                case "performance":
                    if (rows[i].className == "performance")
                        rows[i].style.visibility="visible";
                    break;
                case "portability":
                    if (rows[i].className == "portability")
                        rows[i].style.visibility="visible";
                    break;
                case "trivial":
                    if ((rows[i].className == "style") || (rows[i].className == "information"))
                        rows[i].style.visibility="visible";
                    break;
                case "all":
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
.idcolumn {text-align:center;}
.typecolumn {text-align:center;font-weight:bold;color:#1a1a1a;text-transform:capitalize;padding:4px;}
.desccolumn {padding-left:8px;}
.error .typecolumn {background-color:#CC3333;}
.warning .typecolumn {background-color:#FF9900;}
.style .typecolumn {background-color:#99FF99;}
.performance .typecolumn {background-color:#FFFF66;}
.information .typecolumn {background-color:#3399FF;}
.portability .typecolumn {background-color:#6666CC;}
.paragraph {padding-bottom:5px;padding-top:5px;clear:left;}
.stats {float:right;margin-top:0px;border: 2px solid #666666;padding:5px;background-color:#DDDDDD;}
</style>
<title>MythTV cppCheck Report</title>
</head>
<body>

HEADER

# Instantiate an instance of XML::Simple
my $xs = XML::Simple->new();

# Read and parse the xml document
my $document = $xs->XMLin($file, ForceArray => ['location'], KeyAttr => '');

# Assign the parsed <error> elements to an array
my @errors = @{$document->{errors}->{error}};

# Variables for the statistical information displayed
my $total = @errors;
my $total_error = 0;
my $total_warning = 0;
my $total_performance = 0;
my $total_portability = 0;
my $total_information = 0;
my $total_style = 0;

# Do a first pass over the error array, we need to create a int for each
# category to sort by.
# We also take the opportunity to get a total of each error category for
# display
#
# This cannot be replaced by a custom sorting function since we need the index
# for the dynamic javascript sorting too
foreach my $error (@errors) {

    my $order = 0;
    my $severity = $error->{severity};
    switch ($severity) {
        case "error"
        {
            $order = 1;
            $total_error++;
        }
        case "warning"
        {
            $order = 2;
            $total_warning++;
        }
        case "performance"
        {
            $order = 3;
            $total_performance++;
        }
        case "portability"
        {
            $order = 4;
            $total_portability++;
        }
        case "information"
        {
            $order = 5;
            $total_information++;
        }
        case "style"
        {
            $order = 6;
            $total_style++;
        }
        else
        {
            $order = 7;
        }
    }
    $error->{order} = $order;
}

# Print Heading
print OF <<"HEADING";
<div class="stats">
    <div class="paragraph" style="font-size:1.3em;">There are $total total results</div>
    <div class="paragraph" style="font-size:0.8em;"> $total_error errors,
        $total_warning warnings, $total_performance performance,
        $total_portability portability,<br /> $total_information information,
        $total_style style</div>
</div>
<div>
    <img src="https://www.mythtv.org/img/mythtv.png" alt="MythTV" style="float:left;padding-right:10px;"/>
    <h1 style="padding-top:15px;">cppcheck Report</h1>
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
                            <option value="important" style="color:#CC3333;">Important</option>
                            <option value="performance" style="color:#FFFF66;">Performance</option>
                            <option value="portability" style="color:#6666CC;">Portability</option>
                            <option value="trivial" style="color:#99FF99;">Trivial</option>
                        </select>
                    </fieldset>
                </form>
            </div>
        </td>
    </tr>
</table>
HEADING

# Print Error Table
print OF <<"TABLE_START";
<table class="sortable" style="clear:both;" id="errors">
    <tr>
        <th>#</th>
        <th>Severity</th>
        <th>Description</th>
        <th>File</th>
    </tr>
TABLE_START

# Sort the array using the 'order' attributes we calculated above
my @sorted_errors = sort {$a->{order} cmp $b->{order}} @errors;

# We count from one here, this is not an iterator/index
my $i = 1;
# Iterate over the error list formatting each into a table row
foreach my $error (@sorted_errors) {

    # Create the list of links to the cgit source browser
    # A warning can refer to multiple locations in a file
    my $locations;
    foreach my $location (@{$error->{location}}) {
        $locations .= "<a target=\"_blank\" href=\"https://code.mythtv.org/cgit/mythtv/tree/" . $location->{file} . "#n" . $location->{line} . "\">". $location->{file} . ":" . $location->{line} . "</a><br />";
    }

    # The description may contain characters which must be encoded for HTML
    my $description = substr(encode_entities($error->{msg}), 0, 256);
    # Insert spaces to allow proper wrapping in long semi-colon lists
    $description =~ s/;/; /g;
    my $verbose_desc = encode_entities($error->{verbose});

print OF <<"TABLE_ROW";
        <tr class="$error->{severity}">
            <td class="idcolumn" id="L$i">$i</td>
            <td class="typecolumn $error->{severity}" title="$error->{id}">
                <span style="display:none;">$error->{order}</span> <!-- For sorting column -->
                <span>$error->{severity}&nbsp;</span>
            </td>
            <td class="desccolumn" title="$verbose_desc">
                <span>$description</span>
            </td>
            <td class="locationcolumn">
                <span>$locations</span>
            </td>
        </tr>
TABLE_ROW
    $i++;
}

# Print error table close tag
print OF <<"TABLE_END";
</table>
TABLE_END

# Format the current GMT date to a string to show when this html was generated
my $timestamp = POSIX::strftime("%e %b %Y %H:%M:%S", gmtime);

# Print the page footer
print OF <<"FOOTER";
<div style="text-align:center;">
    <br />
    <a href="http://cppcheck.sourceforge.net/">cppcheck</a> version - $document->{cppcheck}->{version}<br />
    Updated $timestamp GMT
</div>
</body>
</html>
FOOTER

close OF;
