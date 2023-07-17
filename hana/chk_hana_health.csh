#!/bin/csh

###################################################################
###       Author        : Kuldeep Rajpurohit                    ###
###       Cuser ID      : C5315737                              ###
###       Last updated  : 17th July 2023                        ###
###       Title         : GLDS HANA DB Premium health check     ###
###################################################################

# NOTE : Pass SID as command line argument


# Purpose of the script :
# Monitor the basic checks for a HANA system like :
# 1. DB availability
# 2. FS utilization
# 3. Data Utilization
# 4. Key connectivity
# And mail the report via mail to GLDS DB team DL.




# Create a temporary log file for report
touch /tmp/premium_db_health_check.log
echo "Hello Team,\n\n" >> /tmp/premium_db_health_check.log


set sid=$1
set hostname=`hostname -f`
set db_services=`hdbsql -U GHADMIN -ajx "select status, value from sys.m_system_overview where name='All Started'"`


echo "SID : ${sid}" >> /tmp/premium_db_health_check.log
# echo "Hostname : ${hostname}" >> /tmp/premium_db_health_check.log


set flag=0
# Check DB status
if ($db_services == '"OK","Yes"') then
    echo "DB Status : Up" >> /tmp/premium_db_health_check.log
else
    set flag=1
    echo "DB Status : Down" >> /tmp/premium_db_health_check.log
endif


echo "\n\nMount Utilizations :" >> /tmp/premium_db_health_check.log
# Check mount utilizations 
df -lh | grep -i dev >> /tmp/premium_db_health_check.log

# Check Key connections
echo "\n\nKey Connectivity\n" >> /tmp/premium_db_health_check.log
if ($flag == 0) then
    echo "GHADMIN : Successful" >> /tmp/premium_db_health_check.log
    
    # check GHTADMIN key connectivity
    set ghtadmin=`hdbsql -U GHADMIN -ajx "select status, value from sys.m_system_overview where name='All Started'"`
    if ($ghtadmin == '"OK","Yes"') then
        echo "GHTADMIN : Successful" >> /tmp/premium_db_health_check.log
    else
        echo "GHTADMIN : Failed" >> >> /tmp/premium_db_health_check.log
    endif

    # check BKPMON key connectivity
    set bkpmon=`hdbsql -U BKPMON -ajx "select status, value from sys.m_system_overview where name='All Started'"`
    if ($bkpmon == '"OK","Yes"') then
        echo "BKPMON : Successful" >> /tmp/premium_db_health_check.log
    else
        echo "BKPMON : Failed" >> /tmp/premium_db_health_check.log
    endif

else
    echo "DB is down, hence key connectivity will not work.\n\n" >> /tmp/premium_db_health_check.log
endif


# add date when script was executed
set date=`date`

# DB level utilization
echo "\n\nDB Level Data Utilization : " >> /tmp/premium_db_health_check.log
echo "Total in GB, Used in GB" >> /tmp/premium_db_health_check.log
set db_level_utilization=`hdbsql -U GHTADMIN -ajx "select cast(sum(v.total_size / 1024 / 1024 / 1024) as DECIMAL(10,2)) AS Total_in_GB, cast(sum(v.used_size / 1024 / 1024 / 1024) as DECIMAL(10,2)) AS USED_in_GB from M_VOLUME_FILES v, M_SERVICES s where v.file_type = 'DATA' and s.host = v.host and s.port = v.port;"`
echo $db_level_utilization >> /tmp/premium_db_health_check.log


echo "\n\nChecked on : ${date}\n\n" >> /tmp/premium_db_health_check.log

echo "Best Regards,\nGLDS DB Team\n" >> /tmp/premium_db_health_check.log
cat /tmp/premium_db_health_check.log | mail -s "Global Labs IT DB Health Check Report for ${sid}" kuldeep.rajpurohit@sap.com


rm -rf /tmp/premium_db_health_check.log
