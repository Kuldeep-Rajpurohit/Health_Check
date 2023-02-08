#!/usr/bin/perl

use strict;

my $report =0;
$report = 1 if ($ARGV[0] =~ m/report/i);
print localtime() . " - Report=$report\n - ";

my $SID = $ENV{DB2DBDFT};
my $host = `hostname`; chomp $host;
$SID = 'SID not found' unless $SID;

my @dbStateOutput = qx /db2 connect to $SID/;
foreach (@dbStateOutput) { chomp; }


my $outputOnline  = grep {/Database Connection Information/} @dbStateOutput; # chomp $outputOnline;
my $outputOK      = grep {/DB2$SID/} @dbStateOutput;     # chomp $outputOK;
my $numOfLines    = @dbStateOutput;                 print "$numOfLines - ";

print "Output=<@dbStateOutput> - ";
print "OutputOK=$outputOK - ";
print "Result=" . $dbStateOutput[$numOfLines-1] . " - ";
print "Online=$outputOnline\n";


my @fsOutput = qx /df -h | grep db2\/\'$SID'/;
# foreach (@fsOutput) { chomp; }
# my @logdirOutput = qx /df -h | grep $SID/;
# foreach (@logdirOutput) { chomp; }
my @instMemory = qx /db2 get dbm cfg | grep INSTANCE_MEMORY/;
foreach (@instMemory) { chomp; }
my @dbMemory = qx /db2 get db cfg for $SID | grep DATABASE_MEMORY/;
foreach (@dbMemory) { chomp; }
my @dbRunstats = qx /db2 get db cfg for $SID | grep AUTO_RUNSTATS/;
foreach (@dbRunstats) { chomp; }

my @dumpOutput = qx /df -h | grep $SID\/\db2dump/;
foreach (@dumpOutput) { chomp; }
# my $archiveOutput1 = qx /df -h | grep archive/;

# my $numOfLines    = @AutologOutput;                # print "$numOfLines - ";
# my $outputDbstate = grep {/0/} @dbStateOutput;
my $fsOutput = @fsOutput[$numOfLines-0]; 
# my $DbMemory[1]= @dbMemory;

# print "log_dirFS=(@logdirOutput)\n - ";
print "DataFS=(@fsOutput)\n - ";
print "InstMemory=(@instMemory)\n - ";
print "DatabaseMemory=(@dbMemory)\n - ";
print "DB Runstat=(@dbRunstats)\n - ";
print "Memory = $#dbMemory\n - ";

if ($outputOK) {
               if ($outputOnline) {
                print "DB is online: " . localtime() . "\n";
                sendMail ('DL_GLOBAL_IT_LIT_DEV_PREMIUM_SUPPORT@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Global Labs IT Premium DB6 DB $SID is online!
DB6 Memory Status for $SID:

@instMemory
@dbMemory

Current Status OF Runstats:

@dbRunstats

Complete DB6 FS Status of $SID :
Filesystem                 size   used  avail capacity  Mounted on
@@fsOutput !\n") if ($report);
        } else {
                print "DB is not online: " . localtime() . "\n";
                sendMail ('DL_GLOBAL_IT_LIT_DEV_PREMIUM_SUPPORT@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Global Labs IT Premium DB6 DB $SID is offline!
DB6 Memory Status for $SID:

@instMemory
@dbMemory


Current Status OF Runstats:

@dbRunstats
Complete DB6 FS Status of $SID :
Filesystem                 size   used  avail capacity  Mounted on
@@fsOutput !\n");


        }

}



# if ($outputOK1) {
#              if ($outputDbstate) {
#               print "Number of Bad Indexes: $Bad_indexes " . localtime() . "\n";
#               sendMail ('DL_DL_SAP_IT_IS_PREMIUM_SUPPORT@exchange.sap.corp', "SC A Premium MAXDB DB $SID no Bad Indexes found", "online.") if ($report);
#       } else {
#               print "Number of Bad Indexes: $Bad_indexes " . localtime() . "\n";
#               sendMail ('DL_DL_SAP_IT_IS_PREMIUM_SUPPORT@exchange.sap.corp', "SC A Premium MAXDB DB $SID Number of Bad Indexes: $Bad_indexes !\n :-(\n", );
#       }
#}



sub sendMail {
    my $addressee = shift;
    my $alertMsg  = shift;
    my $subject   = shift;

    print "sendMail to $addressee with $alertMsg\n";

    $alertMsg = "Hello!\n\n" . $alertMsg;

    my $time4Sending = localtime();
    my $tmpFile = '/tmp/alive.txt';

    my $subjectLine = "'Global Labs IT Premium DB Proactive Health Check ";
    $subjectLine   .= ($report) ? "Report " : "";
    $subjectLine   .= "for $SID on $host: $subject'";

    $alertMsg .= "\nChecked: $time4Sending\n\nKind regards from $host.\n\n\nYours,\nSqd $SID\n";
    open (MAILFH, ">$tmpFile");
    print MAILFH $alertMsg;
    close MAILFH;

    system ("cat $tmpFile | mailx -s $subjectLine $addressee");
    unlink ($tmpFile);
}
