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

global class C501_Send_Single_SMS {

    @future(callout=true)
    global static void SendSingle_Future(String toNum,String message) {

        TwilioConfig__c tc = TwilioConfig__c.getOrgDefaults();

        String acctId = tc.AccountSid__c;
        String authToken = tc.AuthToken__c;
        String messServiceId = tc.messServiceID__c;
        String fromNumber = tc.fromNumber__c;
        Boolean goodtosend=false;

        TwilioSF.TwilioApiClient clt = new TwilioSF.TwilioApiClient();
        //Switch for throwing exceptions,=.
        //clt.setThrowExceptionsOnFailedResponses();
        clt.addUrlPart('Accounts');
        clt.addUrlPart(acctId);
        clt.addUrlPart('Messages.json');
        clt.addParam('To', toNum);

        if (!String.isBlank(messServiceId)) {

            clt.addParam('MessagingServiceSid', messServiceId); 
            goodtosend = true;
        } else if (!String.isBlank(fromNumber)) {

            clt.addParam('From','+1' + fromNumber);
            goodtosend = true;
        }
        
        clt.addParam('Body', message);

        if(goodtosend) {

            if (!Test.isRunningTest()){

                TwilioSF.TwilioApiClientResponse response = clt.doPost();
                system.debug('++++Twilio response++++ '+ response);
                system.debug('++++Twilio Has Errors++++ '+ response.hasError());
                // stringList.add(string.valueOf(response.hasError()));
                system.debug('++++Twilio Error Message++++ '+ response.getErrorMessage());
            }
        }
    }
}