
# JIRA Plugin for MSM

## MSM-JIRA intergration

This plugin allows you to **Create**, **View**, **Link** and **Unlink** JIRA issues from within MSM. This is achieved by linking the MSM request number to a custom field that has already been configured within JIRA.

## JIRA-MSM intergration 

Within JIRA you can set up multiple WebHooks for different transitions. This allows you to move the MSM request status
during transitions. 

**Setting up JIRA WebHooks:**

Within your JIRA instance follow the steps outlined below:

1. The WebHooks link can be found under the advanced section in the system administation page.
2. Create a WebHook button is found in the top right.
3. The options can be configured to your requirements however the URL needs to be the Plugin endpoint,
this will be something similar to this. `http://[ServerName]/MSM/RFP/Plugins/marval/marvalsoftware.jira/2.0.0/handler/ApiHandler.ashx`
4. We also need to provide the action that we want to perfom and the name of status we want to move to, this can be achived by passing the following paramaters on the queryString
`action=MoveStatus&status=[StatusName]`.

**Connecting workflow transitions to WebHooks:**

1. Workflows can be found under the workflows section in the issues administration page.
2. Click the edit link of the workflow you want to edit.
3. Select the transition you want to trigger the WebHook on. 
4. Once selected options will appear to the right, select the Post Functions link.
5. The "Add Post Function" link can be found in the top right, select the "Trigger a WebHook" option.
6. A dropdown will contain a list of all your WebHooks, select the one you have just created and click add.

When a JIRA issue is moved to the status with that transition it will call the WebHook created, if the satus is a valid next state the MSM request will move state, 
if the status is not valid a note will be added to the request.

## Compatible Versions

| Plugin  | MSM         | JIRA     |
|---------|-------------|----------|
| 1.0.0   | 14.3.0      | v7+      |
| 2.0.0   | 14.4.0      | v7+      |
| 2.0.1   | 14.5.0      | v7+      |
| 3.0.0   | 14.9.0      | v7+      |

## Installation

Please see your MSM documentation for information on how to install plugins.

Once the plugin has been installed you will need to configure the following settings within the plugin page:

+ *JIRA Base URL* : The URL (including port) of your JIRA instance. `http://jira:8080/`
+ *JIRA Custom Field ID* : The ID of the custom field within JIRA that contains the MSM request number. `CT_101_100`
+ *JIRA Custom Field Name* : The name of the custom field within JIRA that contains the MSM request number. `MSM Request Number`
+ *JIRA Username* : The username for authentication with JIRA.
+ *JIRA Password* : The password for authentication with JIRA.
+ *MSM API Key* : The API key for the user created within MSM to perfom these actions.

We recommend that you create a new user within JIRA instead of re-using an existing account. This will allow you to revoke access should you want to, we also suggest creating a new user within MSM. 

## Usage

The plugin can be launched from the quick menu after you load a request.

## Contributing

We welcome all feedback including feature requests and bug reports. Please raise these as issues on GitHub. If you would like to contribute to the project please fork the repository and issue a pull request.
