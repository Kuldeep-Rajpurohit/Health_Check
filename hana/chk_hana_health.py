#! /usr/bin/env python3.8


import os, sys
import smtplib
import subprocess
from socket import gethostbyaddr, gethostname


class final:
    matter = ""


def sendMail(msg, sid):
    smtpServer = 'localhost'
    hostname = gethostbyaddr(gethostname())[0]
    sender = 'root@{}'.format(hostname)
    text = """Hi Team,\n\n{}\n\nBest Regards,\nGLDS DB Team\n\n""".format(msg)
    subject = "Global Labs IT DB Health Check Report for {} on {}".format(sid, hostname)
    message = 'Subject: {}\n\n{}'.format(subject, text)
    # notification_receivers = ['DL_5F97A8BB7883FF027EE82632@global.corp.sap','kuldeep.rajpurohit@sap.com']
    notification_receivers = ['kuldeep.rajpurohit@sap.com']
    try:
        smtpObj = smtplib.SMTP(smtpServer)
        smtpObj.sendmail(sender, notification_receivers, message)
        # print("Email Successfully sent")
    except smtplib.SMTPException:
        print("Error: unable to send email")
        exit(2)


def unix_cmd(cmd):
    temp = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = temp.communicate()
    returncode = temp.returncode
    return(output.decode())


def check_key_connectivity(user, key):
    try:
        cmd = """su - {} -c \"hdbsql -U {} -j '\\s' \" """.format(user, key)
        output = unix_cmd(cmd)
        # print(output)
        if "host" in output.lower() and "sid" in output.lower() and "dbname" in output.lower() and "user" in output.lower() and "kernel version" in output.lower():
            # return True
            final.matter = final.matter + " {} : Connection successfull\n".format(key)
        else:
            # return False
            final.matter = final.matter + " {} : Connection failed\n".format(key)
    except:
        final.matter = final.matter + "ERROR finding {} status.".format(key)
        exit(0)


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
        try:
            temp = self.temp_data.split('/')[2].lower()
            self.db_user = temp + 'adm'
            self.inst_no = self.db_user[1:3]
            self.hostname = os.uname()[1].strip()
            cmd = """cat /etc/fstab | grep -i sapmnt | grep -iv sapmnt_db | awk '{print $2}' """
            output = unix_cmd(cmd)
            self.sid = output.split("/")[2].strip()
            self.app_user = self.sid.lower()+"adm"
            self.sys_pass = None
            self.schema_user = None
            final.matter = final.matter + "\n      Instance number          :   {}".format(self.inst_no)
            # print("      DB user                  : {}".format(self.db_user))
            final.matter = final.matter + "\n      SID                      :   {}".format(self.sid)
            # print("      App user                 : {}".format(self.app_user))
            return
        except:
            final.matter = final.matter + "\nUnable to get system details."
            exit(0)  

            
    def get_db_status(self):
        try:
            cmd = """su - {} -c \"sapcontrol -nr {} -function GetProcessList\" 2>/dev/null | grep -i hdb """.format(self.db_user, self.inst_no)
            output = unix_cmd(cmd)
            if "yellow" in output.lower() or "gray" in output.lower():
                self.db_status = False
            else:
                self.db_status = True
            return self.db_status
        except:
            final.matter = final.matter + "\n **ERROR**   :    DB services are not running."
            exit(0)

    
    def data_usage_db_level(self):
        try:
            # command with query to get data utilization of tenant database
            cmd1 = """su - {} -c \"hdbsql -U GHTADMIN -ajx <<EOF 
            select sum(round(v.total_size / 1024 / 1024 / 1024)), sum(round(v.used_size / 1024 / 1024 / 1024)) from M_VOLUME_FILES v, M_SERVICES s where v.file_type = 'DATA' and s.host = v.host and s.port = v.port;
            exit
            EOF\" | tail -1 """.format(self.db_user)
            data_util_values = unix_cmd(cmd1)
            final.matter = final.matter + "\n" + data_util_values
        except:
            final.matter = final.matter + "\nUnable to get data utilization from DB level."
        
    def check_oom_in_traces(self):
        try:
                
            # get trace path cdtrace from alias
            cmd = "su - {} -c 'cdtrace ; pwd'".format(self.db_user)
            trace_path = unix_cmd(cmd).strip()
            # check if oom files are generated in last 24 hours
            cmd2 = """find {} -mtime 1 -iname ="*oom*" | wc -l""".format(trace_path)
            number_of_oom_traces = int(unix_cmd(cmd2).strip())
            final.matter = final.matter + "\n\nNumber of oom traces in last 24 hours : {}".format(number_of_oom_traces,)
        except:
            final.matter = final.matter + "\n\nError checking oom files in trace path. Check manually."


def main():
    hana = Hana()
    is_hana = hana.check_db_type()
    if is_hana:
        hana.get_sys_details()
        # step 1: check DB availability
        if hana.get_db_status():
            final.matter = final.matter + "\n      DB Status                :   UP\n"
        else:
            final.matter = final.matter + "\n      DB Status                :   Down\n"
    

    # step 2 : fs utilization 
    cmd = "df -lh | grep -iv tmp"
    output = unix_cmd(cmd)
    final.matter = final.matter + "\n" + output

    # key connectivity
    final.matter = final.matter + "\n\nKey connectivity : \n"
    keys = [[hana.db_user, "GHADMIN"],
    [hana.db_user, "GHTADMIN"],
    [hana.db_user, "BKPMON"],
    [hana.app_user, "DEFAULT"]]

    for each in keys:
        check_key_connectivity(each[0], each[1])


    # data utilization from DB level
    final.matter = final.matter + "\n\nDB level utilization : "
    hana.data_usage_db_level()


    # oom check in trace path
    hana.check_oom_in_traces()

    sendMail(final.matter, hana.sid)
    # print(final.matter)


if __name__ == '__main__':
    main()
