###################################################################
###       Author        : Kuldeep Rajpurohit                    ###
###       Cuser ID      : C5315737                              ###
###       Last updated  : 21st March 2023                       ###
###       Title         : GLDS HANA DB Premium health check     ###
###################################################################

# Purpose of the script :
"""
Monitor the basic checks for a HANA system like :
1. DB availability
2. FS utilization
3. Data Utilization
4. Log Utilization
5. Key connectivity
6. OOM dumps during current timestamp

And mail the report via mail to GLDS DB team DL.
"""

import os, sys
import smtplib
import subprocess
import getopt
from socket import gethostbyaddr, gethostname


class report:
    matter = ""


try:
    argv = sys.argv[1:]
    opts, args = getopt.getopt(argv, "s:p")
except:
    print('Error in providing in command line arguments')
    print('<scriptname.py> -s SID')


def unix_cmd(cmd):
    temp = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = temp.communicate()
    returncode = temp.returncode
    return(output.decode())


def check_key_connectivity(key):
    try:
        cmd = """hdbsql -U {} -j '\\s' """.format(key)
        output = unix_cmd(cmd)
        # print(output)
        if "host" in output.lower() and "sid" in output.lower() and "dbname" in output.lower() and "user" in output.lower() and "kernel version" in output.lower():
            report.matter = report.matter + "\n{} : Successful".format(key)
        else:
            report.matter = report.matter + "\n{} : Failed".format(key)
    except:
        report.matter = report.matter + "\n{} : ERROR checking status.".format(key)
        # exit(0)


def get_sid():
    for name, value in opts:
        if name in ['-s']:
            if len(value) == 3:
                return(value)
            else:
                print("Incorrect SID provided, SID should be of 3 chars.")
                exit()


def get_instance_no():
    try:
        cmd = "printenv SAPSYSTEMNAME"
        output = unix_cmd(cmd)
        inst_no = output.strip()[1:]
        return(inst_no)
    except:
        print("Error getting value of SAPSYSTEMNAME env.")
        return('ERROR')


def sendMail(msg, sid):
    cmd = "whoami"
    user = unix_cmd(cmd).strip()
    smtpServer = 'localhost'
    hostname = gethostbyaddr(gethostname())[0]
    sender = '{}@{}'.format(user, hostname)
    text = """Hi Team,\n\n{}\n\n\nBest Regards,\nGLDS DB Team\n\n""".format(msg)
    subject = "Global Labs IT DB Health Check Report for {} on {}".format(sid, hostname)
    message = 'Subject: {}\n\n{}'.format(subject, text)
    notification_receivers = ['kuldeep.rajpurohit@sap.com', 'DL_5F97A8BB7883FF027EE82632@global.corp.sap']

    try:
        smtpObj = smtplib.SMTP(smtpServer)
        smtpObj.sendmail(sender, notification_receivers, message)
        # print("Email Successfully sent")
    except smtplib.SMTPException:
        print("Error: unable to send email")
        exit(2)


class Hana:

    def check_db_type(self):
        try:
            cmd = """cat /etc/fstab | grep -i sapdata1 | awk '{print $2}' """
            output = unix_cmd(cmd).strip()
            self.temp_data = output
            # db type is hana
            if 'hdb' in output:
                self.is_hana = True
            # db type is not hana
            else:
                self.is_hana = False
        except:
            # not a hana system or not standard fs
            self.is_hana = False
        return(self.is_hana)


    def get_sys_details(self):
        self.sid = get_sid()

        # get instance no
        self.inst_no = get_instance_no()

        report.matter = report.matter + "\nSID     : {}".format(self.sid)
        report.matter = report.matter + "\nInst no : {}".format(self.inst_no)


    def mount_utilization(self):
        report.matter = report.matter + "\n\n\nMount utilization : \n"
        cmd = "df -lh | grep -i dev"
        output = unix_cmd(cmd)
        report.matter = report.matter + "\n" + output


    def check_db_status(self):
        cmd = """sapcontrol -nr {} -function GetProcessList""".format('10')
        output = unix_cmd(cmd)
        if "yellow" in output.lower() or "grey" in output.lower():
            self.db_is_up = False
        else:
            self.db_is_up = True
        return(self.db_is_up)


    def check_key_connections(self):
        report.matter = report.matter + "\n\nKey Connectivity : "
        keys = ['GHADMIN', 'GHTADMIN', 'BKPMON']
        for key in keys:
            check_key_connectivity(key)


    def data_usage_db_level(self):

        report.matter = report.matter + "\n\nDB level utilization : "
        cmd = """ hdbsql -U GHTADMIN -ajx \"select sum(round(v.total_size / 1024 / 1024 / 1024 )), sum(round(v.used_size / 1024 / 1024 / 1024)) from M_VOLUME_FILES v, M_SERVICES s where v.file_type = 'DATA' and s.host = v.host and s.port = v.port;\" """
        output = unix_cmd(cmd)
        total, used = output.split(',')
        total = int(float(total))
        used = int(float(used))

        report.matter = report.matter + "\nTotal size : {} GB".format(total)
        report.matter = report.matter + "\nUsed size  : {} GB".format(used)


    def check_oom_in_traces(self):
        cmd = """ cdtrace ; pwd"""
        trace_path = unix_cmd(cmd).strip()

        # check if oom files are generated in last 24 hours
        cmd2 = """ find {} -mtime 1 -iname '*oom*' | wc -l """.format(trace_path)
        no_of_traces = int(unix_cmd(cmd2).strip())
        report.matter = report.matter + "\n\n\nNumber pf OOM traces generated in last 24 hours : {}".format(no_of_traces)


def main():
    hana = Hana()
    is_hana = hana.check_db_type()
    if is_hana:
        hana.get_sys_details()
        # mount utilization 
        hana.mount_utilization()

        if hana.check_db_status():
            report.matter = report.matter + "\nDB Status : UP\n"
            # check key connections
            hana.check_key_connections()
            hana.data_usage_db_level()
        else:
            report.matter = report.matter + "\nDB Status : Down\n" 
        # check for oom traces
        hana.check_oom_in_traces()
    else:
        print("Not a Hana system.")
        # uncomment below line if you want to end mail for non hana systems
        # sendmail("Not a Hana System.")
    
    sendMail(report.matter, hana.sid)
    # print(report.matter)


if __name__ == '__main__':
    main()
