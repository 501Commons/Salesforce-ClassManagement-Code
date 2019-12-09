trigger C501_II_LeadTrigger on Lead (after insert) {

    String subject = 'Class Registered Email Notification';
    List<Task> tasks = new List<Task>();
    for (Lead leadInserted : trigger.new) {
    
        if (String.isBlank(leadInserted.Class_Type__c)) {
            continue;
        }

        // Default OwnerId = 0056A000000qgpsQAA - Training User to make sure task does not sync to external Google Calendar
        //  Future Fix: Don't hardcode the OwnerId - query from SOQL
        tasks.add(new Task(
            Subject = subject,
            Status = 'Completed',
            Priority = 'Normal',
            Description = leadInserted.Class_Type__c,
            ActivityDate = Date.Today(),
            WhoId = leadInserted.Id
            //,OwnerId = '0056A000000qgpsQAA'
            ));
    }

    if (!tasks.isEmpty()) {
        Database.insert(tasks, false);
    }
}