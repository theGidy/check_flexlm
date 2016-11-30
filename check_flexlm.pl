#! /usr/bin/perl -w
#==============================================================#
# check_flexlm.pl - check status of FLEXlm license servers     #
#                    (A Perl plugin for Nagios)                #
#==============================================================#
#                                                              #
#                     check_flexlm.plx v1.0                    #
#                                                              #
#                       Aerojet Virginia                       #
#                      Engineering Network                     #
#                                                              #
#                        powered by Perl                       #
#                                                              #
# Joshua.Parsell@aerojet.com                   copyright 2007  #
# Philipp.Posovszky@dlr.de
#==============================================================#
#                                                              #
# CHANGELOG:                                                   #
# 2007-01-15 - v1.0.0 - First release.                         #
# 2016-10-12 - v1.1.0 - Add Performance Data, Philipp Posovszky#
# 2016-11-30 - v1.2.0 - Suppor multi sever, Philipp Posovszky  #
#                                                              #
#==============================================================#
#                                                              #
# !!!IMPORTANT!!!                                              #
#                                                              #
# Locate the $path_to_lmutil variable and set the location     #
# for your lmutil executable, which you must obtain from       #
# www.macrovision.com for your OS.                             #
#                                                              #
#==============================================================#
#                                                              #
# You may use and modify this software freely.                 #
# You may not profit from it in any way, nor remove the        #
# copyright information.  Please document changes clearly and  #
# preserve the header if you redistribute it.                  #
#                                                              #
# Joshua Parsell, Aerojet                                      #
#                                                              #
#==============================================================#

#@ MAIN_LOGIC

# DEBUGGING MODULES

 use CGI::Carp qw(fatalsToBrowser set_message);   # ONLY TO BE USED FOR DEBUGGING


#@ USE_STATEMENTS
use strict;
use CGI qw(:standard escape escapeHTML);
#@ USE_STATEMENTS



my $help_msg = <<HELPMSG;

 -=-==================-=-
 -=- check_flexlm.pl -=-
 -=-==================-=-

 copyright 2007 Joshua C. Parsell
 Joshua.Parsell\@aerojet.com

 v 1.1.0

 Purpose: CHECK_FLEXLM.PL is a Nagios plugin which checks the status of a
                FLEXlm license server.  If everything is running correctly, you
                get an OK.  If one or more modules are currently maxed out, you
                get a WARNING.  If there is some sort of error, like the license
                server isn't running or can't be reached, you get a CRITICAL.

                You should supply a port number.  If none is given, port 27000
                is assumed.

                Vendor daemon is optional. It should be supplied if you want to
                check individual vendor daemons separately, in cases where you
                are serving multiple vendor daemons with one lmgrd over a single
                port number.
                
                Server count is optional. It should be supplied if you have more 
                redudant server as licence servers. 

 Usage:  perl check_flexlm.pl -p port -H hostname [-S vendor_daemon] [-n server_count]

HELPMSG
my $syntax_error = <<SYNERR;

 Incorrect syntax.

 Usage:  perl check_flexlm.plx -H hostname [-p port] [-S vendor_daemon] [-n server_count]
  -OR-   perl check_flexlm.plx --help

SYNERR

# Test the number of arguments on the command line to make sure we are using the right syntax.
if ((@ARGV > 6)||(@ARGV eq "0"))
{
	print "\n ERROR: Wrong number of arguments.\n";
	print $syntax_error;
	exit;
}
# Did they ask for help?
if ($ARGV[0] eq "--help")
{
	print $help_msg;
	exit;
}

my ($port, $server);
my $vendor = 0;
my $serverCount = 1;

my %arg_hash = @ARGV;
# Make sure only the correct options are being used.
foreach (keys %arg_hash)
{
	if (($_ ne "-p")&&($_ ne "-H")&&($_ ne "-S")&&($_ ne "-n"))
        {
                print "\n ERROR: Invalid option: " . $_ . "\n";
                print $syntax_error;
                exit;
        }
        $port = $arg_hash{"-p"} if ($_ eq "-p");
        $vendor = $arg_hash{"-S"} if ($_ eq "-S");
        $server = $arg_hash{"-H"} if ($_ eq "-H");
        $serverCount= $arg_hash{"-n"} if ($_ eq "-n");
}



my $content;                                            # main page content
my $path_to_lmutil = "/usr/local/exelis/idl82/bin/lmutil"; # path to the lmutil executable on the system.  Make sure the web server user can run it!

$port = "27000" if (!$port); # Default to 27000 for port

my $lmstat_output;
if ($vendor) {
        $lmstat_output = `$path_to_lmutil lmstat -S $vendor -c $port\@$server`;  # Get output of lmstat for $vendor_daemon only
        #print $lmstat_output . "\n";  #DEBUG ONLY
} else {
        $lmstat_output = `$path_to_lmutil lmstat -a -c $port\@$server`;  # Get output of lmstat from port $port on FLEXlm server $server
        #print $lmstat_output . "\n";  #DEBUG ONLY
}

my $owc_output = owc_stat ($lmstat_output);

print $owc_output;


exit (0) if ($owc_output =~ /^FLEXlm OK/);
exit (1) if ($owc_output =~ /^FLEXlm WA/);
exit (2) if ($owc_output =~ /^FLEXlm CR/);

#@ MAIN_LOGIC

exit (3);



# owc_stat will read in lmstat output and display its status as CRITICAL, WARNING, or OK
#
# CRITICAL = At least one vendor daemon on this server is down.
# WARNING = All vendor daemons are up, but at least one feature is maxxed out (# issued = # in use).
# OK = All vendor daemons are up, all licensed features have at least one license available for checkout.
#
sub owc_stat {
        my $lmstat_output = shift;
        my $output;
        # Split the lines of $lmstat_output at the newlines.
        my @lmstat_lines = split /\n/, $lmstat_output;
        my $red_flag = 0;
        my $yellow_flag = 0;
        my $yellow_feats = [];
        my $features = 0;

    	my $performanceData = "|";
        for (@lmstat_lines)
        {	
                if ($features eq 0)
                {
                        $red_flag ++ if ((/[Cc]annot/)||(/[Uu]nable/)||(/refused/)||(/down/)||(/[Ww]in[sS]ock/));
                }
                else
                {
                        if (/Users of (.*): .* of ([0-9]+) .* issued; .* of ([0-9]+) .* use/)
                        {
                                 my $available_licenses = $2 - $3;
                                 if ($available_licenses eq 0)
                                 {
                                        $yellow_flag ++;
                                        push @$yellow_feats, $1;
                                 }
                        }
                }
                #Create Perfromance Data
                if (/Users of (.*): .* of ([0-9]+) .* issued; .* of ([0-9]+) .* use/)
                {
                     $performanceData.="$1=$3;;;0;$2 ";
                }

                #if ($curfile =~ /.+_[0-9]{4}\.([a-zA-Z]{3,4})\.Z$/)
                $features ++ if (/Feature usage info:/)||(/Users of features served by $vendor:/);
        }

        if ($red_flag > 0)
        {
                $output = "FLEXlm CRITICAL: License Server Down or Unreachable.";
        }
        elsif ($yellow_flag > 0)
        {
                $output = "FLEXlm WARNING: Maximum Usage Warning for Features: ";
                for my $feat (@$yellow_feats)
                {
                        $output .= $feat . " ";
                }
        }
        else
        {
                $output = "FLEXlm OK: Server is up.  All Modules/Features Available.";
        }

        $output.=$performanceData;
        $output .= "\n";
        return ($output);
}

# ----------------------------------------------------------------------


