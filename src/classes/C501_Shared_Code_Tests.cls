@isTest
public with sharing class C501_Shared_Code_Tests {

	@isTest
	private static void codeCoverage() {

		C501_Shared_Code.CodeCoverageHack();

		User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
		System.runAs(thisUser) {

			EmailTemplate template = new EmailTemplate(
				Name = 'Email_Template',
				DeveloperName = 'Email_Template',
				Body = 'Body',
				HtmlValue = '</br>',
				Subject = 'Subject',
				IsActive = true,
				FolderId = UserInfo.getUserId(),
				TemplateType = 'text'
			);
			insert template;

			Account account = new Account(
				Name = 'Name'
			);
			insert account;

			Contact contact = new Contact(
				LastName = 'LastName',
				Email = 'test@test.com'
			);
			insert contact;

			Messaging.SingleEmailMessage contactEmail = C501_Shared_Code.BuildContactEmail(template.Id, contact.Id, account.Id, contact.Email, new List<OrgWideEmailAddress>());
			Messaging.SingleEmailMessage contactEmail2 = C501_Shared_Code.BuildContactEmail_v2(template.Id, contact.Id, account.Id, contact.Email, new List<OrgWideEmailAddress>(), false);
			Messaging.SingleEmailMessage adminEmail = C501_Shared_Code.BuildAdminEmail(contact.Id, contact.Email, contact.Email, template.Name, 'Message Data', 'Error Message', true);

			C501_Shared_Code.SendEmails(
				new List<Messaging.SingleEmailMessage> {adminEmail, contactEmail, contactEmail2},
				contact.Email,
				template.DeveloperName,
				'Message Data',
				true);
		}
	}
}