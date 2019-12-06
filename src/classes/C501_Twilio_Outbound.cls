public with sharing class C501_Twilio_Outbound {
    @InvocableMethod(label='Twilio Outbound')
    public static void doThing (List<TwilioOutboundInput> inputs) {

        String conId = '';
        String conMphone = '';
        String mess = '';
        String fromN = '';
        String messSID = '';

        List<String> stringList = new List<String>(); 
        for (TwilioOutboundInput input : inputs) {
            if (String.isNotBlank(input.contactId)) {
                conId=input.contactId;
            }
            if (String.isNotBlank(input.contactMphone)) {
                conMphone=input.contactMphone;
            } else {
                //return stringList;
            }
            if (String.isNotBlank(input.message)) {
                mess=input.message;
            } else {
                //return stringList;
            }
        }

        System.debug('Contact Ids: ' + conId);
        System.debug('contactMphone: ' + conMphone);
        System.debug('message: ' + mess);
        System.debug('fromNumber: ' + fromN);

        if (!Test.isRunningTest()){
            C501_Send_Single_SMS.SendSingle_Future(conMphone,mess);
        }
    }

    public class TwilioOutboundInput {
        @InvocableVariable(required=true)
        public String contactId;
        @InvocableVariable(required=true)
        public String contactMphone;
        @InvocableVariable(required=true)
        public String message;
    }
}