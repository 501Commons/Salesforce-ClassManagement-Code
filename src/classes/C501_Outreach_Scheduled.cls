/*
    Copyright (c) 2019, 501Commons.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of 501Commons.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

/*      Run from Developer Console
          C501_Outreach_Scheduled scheduledOutreach = new C501_Outreach_Scheduled();
          scheduledOutreach.execute(null);
*/
//      Apex Schedule via Setp -> Apex Class -> Schedule Apex; Every Day at 10am - 0 10 * * *
//

global class C501_Outreach_Scheduled implements Schedulable {

    global void execute(SchedulableContext SC) {

        // Start batchable Outreach process
        //C501_Outreach_Batch batchOutreach = new C501_Outreach_Batch(); 
        //database.executebatch(batchOutreach);

        // Get the report ID
        Imagine_Settings__c is = Imagine_Settings__c.getOrgDefaults();
        String rDevName = is.Outreach_Report__c;
        String replyemail = is.Reply_Email__c;
        String smsPrefix = is.SMS_Template_Prefix__c;
        String emailPrefix = is.Email_Template_Prefix__c;

        String rQuery='SELECT Id, DeveloperName FROM Report where DeveloperName = \'' + rDevName + '\'';
        List <Report> reportList = Database.query(rQuery);

        //List <Report> reportList = [SELECT Id,DeveloperName FROM Report where 
        //    DeveloperName = '\''+rDevName+'\''];
        String reportId = (String)reportList.get(0).get('Id');

        // Run a report synchronously
        Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);

        // Reports.reportResults ActiveISOContacts = Reports.ReportManager.runReport(reportId, true);
        results.getAllData();
        System.debug('Value of results.getAllData()' + results.getAllData());

        Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
        if (factDetails.getRows().isEmpty()) {

          // Check for Twilio Error Logs
          CheckTwilioLogs();

          return;
        }

        // Get the field value from the first data cell of the first row of the report
        Reports.ReportDetailRow detailRow = factDetails.getRows()[0];
        List<Reports.ReportDetailRow> reportRows = factDetails.getRows();
        for (Reports.ReportDetailRow reportRow : reportRows){

            List<Reports.ReportDataCell> datacells = reportRow.getDataCells();
            if (datacells.isEmpty()) {
              continue;
            }

            Reports.ReportDataCell datacell = datacells[0];
            id campid = (id)datacell.getValue();
            System.debug('Campaign IDs from First Column: '+ campid);

            C501_Outreach_Email_SMS.outboundESinputs outreach;
            outreach = new C501_Outreach_Email_SMS.outboundESinputs();
            outreach.trainingID = campid;
            outreach.replyToAddress = replyemail;
            outreach.smsTemplatePrefix = smsPrefix;
            outreach.emailTemplatePrefix = emailPrefix;
            
            
            C501_Outreach_Email_SMS.doThing(
              new List<C501_Outreach_Email_SMS.outboundESinputs>{ outreach }      
            );
        }

        // Check for Twilio Error Logs
        CheckTwilioLogs();
    }

    private void CheckTwilioLogs() {

      List<TwilioSF__Log__c> twilioLogs = [SELECT Id, TwilioSF__Level__c, TwilioSF__Message__c, TwilioSF__StackTrace__c FROM TwilioSF__Log__c];
      for (TwilioSF__Log__c twilioLog :twilioLogs) {
        if (twilioLog.TwilioSF__Level__c <> 'ERROR') {
          continue;
        }

        C501_Shared_Code.SendAdminAlert(LoggingLevel.ERROR, 'sfconsulting@501commons.org', '*****C501_Shared_Code::SendAdminAlert Twilio Exception: ' + twilioLog.TwilioSF__Message__c);
      }

      if (!twilioLogs.isEmpty()) {
        Database.delete(twilioLogs, false);
      }
    }

}