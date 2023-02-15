#!/usr/bin/perl

use strict;

my $snapshot =0;
my $report =0;
$report = 1 if ($ARGV[0] =~ m/report/i);
$snapshot = 1 if ($ARGV[0] =~ m/snapshot/i);
print localtime() . " - Report=$report\n - ";
print localtime() . " - snapshot=$snapshot\n - ";

my $SID = $ENV{DBNAME};
my $host = `hostname`; chomp $host;
$SID = 'SID not found' unless $SID;

my $notenant = 'No Tenant found because of MAXDB Version';
my @dataOutput = qx /df -lh | grep sapdata/;
foreach (@dataOutput) { chomp; }
my @archiveOutput = qx /df -lh | grep archive/;
foreach (@archiveOutput) { chomp; }
my @cacheOutput = qx /dbmcli -U w sql_execute "select value from MONITOR_CACHES where description = 'Data cache hit rate (%)'"/;
foreach (@cacheOutput) { chomp; }
my @dataAreaOutput = qx /dbmcli -U w sql_execute "select avg(usedsizepercentage) from DATAVOLUMES"/;
foreach (@dataAreaOutput) { chomp; }
# my @dataVolumeSize= qx /dbmcli -U w sql_execute "select max(CONFIGUREDSIZE) from datavolumes"/;
my @dataVolumeSize= qx /dbmcli -U w sql_execute "select configuredsize from datavolumes where id = (select max(id) FROM datavolumes)"/;
# my @dataVolumeSize= qx /dbmcli -U w sql_execute select configuredsize from datavolumes where ID = max(ID)/;
foreach (@dataVolumeSize) { chomp; }
my @TenantVolumeSize= qx /dbmcli -U w sql_execute "select sum(CURRENTSIZE) \/\ 1024 \/\ 1024 from tenantvolumes"/;
foreach (@TenantVolumeSize) { chomp; }
my @dbStateOutput = qx /dbmcli -U w sql_execute select badindexes from SYSDD.DBM_STATE/;
foreach (@dbStateOutput) { chomp; }
my @AutologOutput = qx /dbmcli -U c autolog_show/;
foreach (@AutologOutput) { chomp; }
my @dumpOutput = qx /df -lh | grep \/\sapdb\/\data /;
foreach (@dumpOutput) { chomp; }
my $archiveOutput1 = qx /df -lh | grep archive/;
# my @snapdate = qx /dbmcli -U w sql_execute select CREATEDATE from snapshots/;
my @snapdate = qx /sqlcli -U w select CREATEDATE from snapshots/;
foreach (@snapdate) { chomp; }
my @snapid = qx /dbmcli -U w sql_execute select id from snapshots/;
foreach (@snapid) { chomp; }


my $outputAutolog  = grep {/AUTOSAVE IS ON/} @AutologOutput; # chomp $outputOnline;
my $outputOK      = grep {/OK/} @AutologOutput;     # chomp $outputOK;
my $numOfLines    = @AutologOutput;                # print "$numOfLines - ";
my $outputOK1     = grep {/OK/} @dbStateOutput;     # chomp $outputOK;
my $outputDbstate = grep {/0/} @dbStateOutput;
my $Bad_indexes = $dbStateOutput[$numOfLines-0];
my $CacheHitRatio = $cacheOutput[$numOfLines-0];
my $dataareaoutput = sprintf("%03.2f",$dataAreaOutput[$numOfLines-0]);
my $Archive_FS = @archiveOutput;
my $dataarea = sprintf("%03.2f",$dataareaoutput);
my $datavolumesize= sprintf("%05.0f",@dataVolumeSize[$numOfLines-0]/1024);
my $tenantvolumesize= sprintf("%02.0f",@TenantVolumeSize[$numOfLines-0]);
my $datavolume1size = $datavolumesize/1024;
my $snapid = @snapid[$numOfLines-0]; 
my $snapdate = @snapdate[$numOfLines-0];

print "ArchiveFS=(@archiveOutput[$#archiveOutput])\n - ";
print "DataFS=(@dataOutput)\n - ";
print "DumpFS=(@dumpOutput)\n - ";
print "Output=<@AutologOutput>\n - ";
print "OutputOK=$outputOK\n - ";
print "Result=" . $AutologOutput[$numOfLines-1] . "\n - ";
print "Online=$outputAutolog\n - ";
print "Result1=" . $dbStateOutput[$numOfLines-0] . "\n - ";
print "BadIndexes=$Bad_indexes\n - ";
printf "DataAreaUsed=: $dataareaoutput %\n - ";
print "CacheHitRatio=$CacheHitRatio%\n - ";
print "DataVolumeSize=$datavolumesize MB\n -";
print "DataVolume1Size=$datavolume1size GB\n -";
print "tenantvolumesize=$tenantvolumesize GB\n -";
print "SnapshotId= @snapid[$numOfLines-0]\n -";
print "SnapshotDate= @snapdate[$numOfLines-0]\n -";

if ($outputOK) {
               if ($outputAutolog) {
                print "MAXDB Autolog is on: " . localtime() . "\n";
                sendMail ('DL_GLOBAL_IT_LIT_DEV_PREMIUM_SUPPORT@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Global Labs IT Premium MAXDB DB $SID Autolog is on!
Global Labs IT Premium MAXDB DB $SID Number of Bad Indexes   = $Bad_indexes !
Global Labs IT Premium MAXDB DB $SID Cache Hit Ratio         = $CacheHitRatio%
Global Labs IT Premium MAXDB DB $SID Data Area Used          = $dataareaoutput%
Global Labs IT Premium MAXDB DB $SID Last Data Volume Size   = $datavolume1size GB used for the next DataVolume
Global Labs IT Premium MAXDB DB $SID Tenant Volume Size      = $tenantvolumesize GB (If Error -4004 no Tenant because of MAXDB version)
Global Labs IT Premium MAXDB DB $SID Snapshotinfo         Id = $snapid  (If Error '100,Row not found'  No Snapshot created)
                          SnapshotCreationdate    = $snapdate

Archive,DBdump and Data FS Status of $SID :
Filesystem                         size   used  avail capacity  Mounted on
@dumpOutput
@archiveOutput                     
@@dataOutput !\n") if ($report);
        } else {
                print "MAXDB Autolog is not on: " . localtime() . "\n";
                sendMail ('DL_GLOBAL_IT_LIT_DEV_PREMIUM_SUPPORT@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Autolog is not on by Global Labs IT Premium MAXDB DB $SID !
Global Labs IT Premium MAXDB DB $SID Number of Bad Indexes   = $Bad_indexes !
Global Labs IT Premium MAXDB DB $SID Cache Hit Ratio         = $CacheHitRatio%
Global Labs IT Premium MAXDB DB $SID Data Area Used          = $dataareaoutput%
Global Labs IT Premium MAXDB DB $SID Last Data Volume Size   = $datavolume1size GB used for the next DataVolume
Global Labs IT Premium MAXDB DB $SID Tenant Volume Size      = $tenantvolumesize GB (If Error -4004 no Tenant because of MAXDB version)
Global Labs IT Premium MAXDB DB $SID Snapshotinfo         Id = $snapid  (If Error '100,Row not found'  No Snapshot created)
                          SnapshotCreationdate    = $snapdate
                        
Archive,DBdump and Data FS Status of $SID :
Filesystem                         size   used  avail capacity  Mounted on
@dumpOutput
@archiveOutput    
@@dataOutput !\n");


        }

}



 if ($snapshot) {
               my @Deletesnap = qx /dbmcli -U c db_execute drop snapshot/;
               print "MAXDB DB snapshot ist gelöscht " . localtime() . "\n";
               my @Createsnap = qx /dbmcli -U c db_execute create snapshot/;
               print "MAXDB DB snapshot ist erstellt  " . localtime() . "\n";
       } else {
               print "Snapshot Variante wurde nicht gewaehlt " . localtime() . "\n";
}



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
