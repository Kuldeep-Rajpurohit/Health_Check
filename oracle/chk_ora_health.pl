#!/usr/bin/perl

use strict;

my $GREP   = '___AAA___';
my $RESULT = 'Result';

my $report = 0;
$report = 1 if ($ARGV[0] =~ m/report/i);
print localtime() . " - Report=$report - \n";

my $SID = $ENV{ORACLE_SID};
print "SID=<$SID>, ";
my $host = `hostname`; chomp $host;
print "host=<$host>\n";

my $id = qx /id/;  
my $status = 'open';
my $SQL = '';
my $SQL1 = '';
my $cmd = '';

print $id . "\n";
chk_status();

# print "Status: <" . $status . ">\n";

my @dbStateOutput = split (/\s*\n\s*/, $status); chomp @dbStateOutput;

# print "Zeilen: @dbStateOutput\n";

my $outputOK     = grep {/$RESULT/}             @dbStateOutput;
my $outputOnline = grep {/OPEN/} grep {/$GREP/} @dbStateOutput;
print "Online=$outputOnline, OK=$outputOK\n";

my $SQL1=<<_EOT_;
    sqlplus -S "/ as sysdba" <<.
		select tablespace_name, free_percent
from (
            SELECT b.tablespace_name, b.tablespace_size_mb, sum(nvl(fs.bytes,0))/1024/1024 free_size_mb,
            (sum(nvl(fs.bytes,0))/1024/1024/b.tablespace_size_mb *100) free_percent  
            FROM dba_free_space fs,
                 (SELECT tablespace_name, sum(bytes)/1024/1024 tablespace_size_mb FROM dba_data_files
                  GROUP BY tablespace_name
                 ) b
           where fs.tablespace_name = b.tablespace_name
           group by b.tablespace_name, b.tablespace_size_mb
        ) ts_free_percent
WHERE free_percent < 30 
ORDER BY free_percent;
select b.tablespace_name, tbs_size SizeMb, a.free_space FreeMb from  (select tablespace_name, round(sum(bytes)/1024/1024 ,2) as free_space 
 from dba_free_space group by tablespace_name) a, (select tablespace_name, sum(bytes)/1024/1024 as tbs_size from dba_data_files 
  group by tablespace_name) b where a.tablespace_name(+)=b.tablespace_name;
select TABLESPACE_NAME, (BYTES_USED/1024/1024) USED_MB, (BYTES_FREE/1024/1024)FREE_MB from V\\\$TEMP_SPACE_HEADER;
select FILE_ID,TABLESPACE_NAME,AUTOEXTENSIBLE from dba_data_files where AUTOEXTENSIBLE='NO';
select FILE_ID,TABLESPACE_NAME,AUTOEXTENSIBLE from dba_temp_files where AUTOEXTENSIBLE='NO';
exit;
_EOT_
    
my @TbspOutput = qx /$SQL1/;
#foreach (@TbspOutput) { chomp; }

print "The tablespace usage details:\n (@TbspOutput) \n - ";

my @fsOutput = qx /df -lh | grep '$SID'/;
#my @fsOutput = qx /df -lh/;
#foreach (@fsOutput) { chomp; }

print "DB file system details:\n(@fsOutput)\n - ";

my @archiveOutput1 = qx /df -lh | grep archive/;
#foreach (@archiveOutput1) { chomp; }

print "Archive log directory:\n(@fsOutput)\n - ";



if ($outputOK) {
    if ($outputOnline) {
	print "DB is online: " . localtime() . "\n";
	sendMail ('DL_GLOBAL_IT_LIT_DEV_DBA@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Global Labs IT Premium ORACLE DB $SID is online!
Tablespace usage details for $SID:
@TbspOutput
Complete Oracle FS Status of $SID :
Filesystem                 size   used  avail capacity  Mounted on
@@fsOutput
@@archiveOutput1 !\n - ") if ($report); 
        } else {
                print "DB is not online: " . localtime() . "\n";
                sendMail ('DL_GLOBAL_IT_LIT_DEV_DBA@exchange.sap.corp,DL_5F97A8BB7883FF027EE82632@global.corp.sap', "Global Labs IT Premium ORACLE DB $SID is offline!
Tablespace usage details for $SID:
@TbspOutput
Complete Oracle FS Status of $SID :
Filesystem                 size   used  avail capacity  Mounted on
@@fsOutput
@@archiveOutput1 !\n");


        }

}
sub sendMail {
    my $addressee = shift;
    my $alertMsg  = shift;
    my $subject   = shift;

    print "sendMail to $addressee with $alertMsg\n";

    $alertMsg = "Hello!\n\n" . $alertMsg;

    my $time4Sending = localtime();
    my $tmpFile = '/tmp/alive.txt';

    my $subjectLine = "'Global Labs IT DB Health Check ";
    $subjectLine   .= ($report) ? "Report " : "";
    $subjectLine   .= "for $SID on $host: $subject'";

    $alertMsg .= "\nChecked: $time4Sending\n\nKind regards, \n\n\nGLDS DB TEAM\n";
    open (MAILFH, ">$tmpFile");
    print MAILFH $alertMsg;
    close MAILFH;

    system ("cat $tmpFile | mailx -s $subjectLine $addressee");
    unlink ($tmpFile);
}

sub chk_status {
    my $SQL=<<_EOT_;
    sqlplus -S "/ as sysdba" <<.
SELECT '$GREP' || status AS "$RESULT"
  FROM v\\\$instance;
exit;
_EOT_
    $status = qx /$SQL/;
    return ($status =~ m/open/);  
} # chk_status
 
