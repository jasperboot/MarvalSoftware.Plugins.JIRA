<%@ WebHandler Language="C#" Class="ApiHandler" %>

using System;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Dynamic;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using MarvalSoftware.UI.WebUI.ServiceDesk.RFP.Plugins;
using MarvalSoftware.ServiceDesk.Facade;
using MarvalSoftware.DataTransferObjects;
using System.Threading.Tasks;
using System.Linq;

/// <summary>
/// ApiHandler
/// </summary>
public class ApiHandler : PluginHandler
{
    //properties
    private string CustomFieldName
    {
        get
        {
            return GlobalSettings["JIRACustomFieldName"];
        }
    }

    private string CustomFieldId
    {
        get
        {
            return GlobalSettings["JIRACustomFieldID"];
        }
    }

    private string BaseUrl
    {
        get
        {
            return GlobalSettings["JIRABaseUrl"];
        }
    }

    private string ApiBaseUrl
    {
        get
        {
            return this.BaseUrl + "rest/api/latest/";
        }
    }

    private string MSMBaseUrl
    {
        get
        {
            return HttpContext.Current.Request.Url.Scheme + "://127.0.0.1" + MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath;
        }
    }

    private string MSMAPIKey
    {
        get
        {
            return GlobalSettings["MSMAPIKey"];
        }
    }

    private string Username
    {
        get
        {
            return GlobalSettings["JIRAUsername"];
        }
    }

    private string Password
    {
        get
        {
            return GlobalSettings["JIRAPassword"];
        }
    }

    private string JiraCredentials
    {
        get
        {
            return GetEncodedCredentials(String.Format("{0}:{1}", this.Username, this.Password));
        }
    }

    private string JiraIssueNo { get; set; }

    private string JiraSummary { get; set; }

    private string JiraType { get; set; }

    private string JiraProject { get; set; }

    private string JiraReporter { get; set; }

    private string AttachmentIds { get; set; }

    private string MSMContactEmail { get; set; }

    private string IssueStringDetails { get; set; }

    //fields
    private int MsmRequestNo;
        
    /// <summary>
    /// Handle Request
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        ProcessParamaters(context.Request);

        var action = context.Request.QueryString["action"];
        RouteRequest(action, context);
    }

    public override bool IsReusable
    {
        get { return false; }
    }

    /// <summary>
    /// Get Paramaters from QueryString
    /// </summary>
    private void ProcessParamaters(HttpRequest httpRequest)
    {
        int.TryParse(httpRequest.Params["requestNumber"], out MsmRequestNo);
        JiraIssueNo = httpRequest.Params["issueNumber"] ?? string.Empty;
        JiraSummary = httpRequest.Params["issueSummary"] ?? string.Empty;
        JiraType = httpRequest.Params["issueType"] ?? string.Empty;
        JiraProject = httpRequest.Params["project"] ?? string.Empty;
        JiraReporter = httpRequest.Params["reporter"] ?? string.Empty;
        AttachmentIds = httpRequest.Params["attachments"] ?? string.Empty;
        MSMContactEmail = httpRequest.Params["contactEmail"] ?? string.Empty;
        
        IssueStringDetails = httpRequest.Params["issueDetails"] ?? string.Empty;
        if (!string.IsNullOrEmpty(IssueStringDetails))
        {
            IssueStringDetails = Encoding.UTF8.GetString(Convert.FromBase64String(IssueStringDetails));
        }
    }

    /// <summary>
    /// Route Request via Action
    /// </summary>
    private void RouteRequest(string action, HttpContext context)
    {
        HttpWebRequest httpWebRequest;

        switch (action)
        {
            case "PreRequisiteCheck":
                context.Response.Write(PreRequisiteCheck());
                break;
            case "GetJiraIssues":
                httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("search?jql='{0}'={1}", this.CustomFieldName, this.MsmRequestNo));
                context.Response.Write(ProcessRequest(httpWebRequest, this.JiraCredentials));
                break;
            case "LinkJiraIssue":
                UpdateJiraIssue(this.MsmRequestNo);
                httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("issue/{0}", JiraIssueNo));
                context.Response.Write(ProcessRequest(httpWebRequest, this.JiraCredentials));
                break;
            case "UnlinkJiraIssue":
                context.Response.Write(UpdateJiraIssue(null));
                break;
            case "CreateJiraIssue":
                dynamic result = CreateJiraIssue();
                httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("issue/{0}", result.key));
                context.Response.Write(ProcessRequest(httpWebRequest, this.JiraCredentials));
                break;
            case "MoveStatus":
                MoveMsmStatus(context.Request);
                break;
            case "GetProjectsIssueTypes":
                SortedDictionary<string, string[]> results = GetJIRAProjectIssueTypeMapping();
                context.Response.Write(JsonConvert.SerializeObject(results));
                break;
            case "GetJiraUsers":
                httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("user/search?username={0}", this.MSMContactEmail));
                context.Response.Write(ProcessRequest(httpWebRequest, this.JiraCredentials));
                break;
            case "SendAttachments":
                if (!String.IsNullOrEmpty(AttachmentIds))
                {
                    int[] attachmentNumIds = Array.ConvertAll<string, int>(AttachmentIds.Split(','), Convert.ToInt32);
                    List<AttachmentViewInfo> att = GetAttachmentDTOs(attachmentNumIds);
                    string attachmentResult = PostAttachments(att, JiraIssueNo);
                    context.Response.Write(attachmentResult);
                }
                break;
            case "ViewSummary":
                context.Response.Write(this.BuildPreview());
                break;
        }
    }

    /// <summary>
    /// Build a summary preview of the jira issue to display in MSM
    /// </summary>
    /// <returns></returns>
    private string BuildPreview()
    {
        if (string.IsNullOrEmpty(this.IssueStringDetails)) return string.Empty;

        const string jiraIssueSummaryTemplate = 
@"<html xmlns='http://www.w3.org/1999/xhtml'>
   <head>      
      <style>
            html
            {
                font-family: Arial;
                font-size: 12px;
            }
            #container
            {
                position: absolute;
                top: 0;
                bottom: 0;
                left: 0;
                right: 0;
                padding: 20px;
                overflow: auto;
            }
            @@media print
            {
                #container
                {
                    overflow: visible;
                }
            }
            .jiraIssueHeader
            {            
                padding-left: 42px;
                background: no-repeat 0 center;
                background-image: url('@Model[""projectIconUrl""]');
                vertical-align: middle;
                margin-bottom: 20px;
            }
            h1
            {
                line-height: 20px;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                font-size: 20px;
                margin: 0;
                padding: 0;
                padding-top: 5px;
            }          
            h2 a
            {
                text-decoration: none;
            }
            h2 .notLink:hover
            {
                color: #000;
                cursor: text;
            }
            .panel
            {
                clear: both;
            }
            .panel > h2
            {          
                margin-bottom: 10px;
                border-bottom: 2px solid #d5d5d5;
                font-size: 16px;
            }
            .panel
            {
                margin-top: 10px;
            }
            .panel:first-child
            {
                margin-top: 0;
            }
            .panel .multiColumn
            {
                -moz-column-count: 2;
                -webkit-column-count: 2;
                column-count: 2;
                -webkit-column-width: 250px;
                -moz-column-width: 250px;
                column-width: 250px;
            }
            .panel .keyValueSpan
            {
                display: block;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }
            .panel .keyValueSpan + .keyValueSpan,
            .panel .keyValueSpan + .multiColumn,
            .panel .multiColumn + .keyValueSpan,
            .panel .keyValueSpan + .grid,
            .panel .keyValueDiv + .keyValueDiv,
            .panel .keyValueDiv + .multiColumn,
            .panel .multiColumn + .keyValueDiv,
            .panel .keyValueDiv + .grid
            {
                margin-top: 10px;
            }
            .panel .keyValueSpan,
            .panel .keyValueSpan > *
            {
                vertical-align: middle;
            }
            .panel .keyValueSpan > label,
            .panel .keyValueDiv > label
            {
                display: inline-block;
                width: 100px;
                text-align: center;
                margin-right: 10px;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }
            .panel .keyValueDiv > div
            {
                margin-left: 110px;
                margin-top: -1em;
            }
            .panel .keyValueSpan > span,
            .panel .keyValueSpan > a,
            .panel .keyValueDiv > div
            {
                font-weight: bold;
            }
            .panel .keyValueSpan .jiraType
            {
                padding-left: 18px;
                background: no-repeat 0 center;
                background-image: url('@Model[""issueTypeIconUrl""]');
            }
            .panel .keyValueSpan .jiraStatus
            {
                background-color: @Model[""statusCategoryBackgroundColor""];
                border-color: @Model[""statusCategoryBackgroundColor""];
                padding: 2px;
            }
            .panel .keyValueSpan .jiraPriority
            {
                padding-left: 18px;
                background: no-repeat 0 center;
                background-image: url('@Model[""priorityIconUrl""]');
            }
      </style>
   </head>   
   <body id='body'>        
        <div id='container' class='container'>
            <div id='content' class='content'>
                <div class='jiraIssueHeader'>
                    <a href='@Model[""issueUrl""]' target='_blank'>@Model[""issueProjectAndKey""]</a>
                    <h1 id='heading' title=""@Model[""summary""]"">@Model[""summary""]</h1>
                </div>
                <div class='jiraSummary'>
                    <div id='details' class='panel'>
                        <h2>Details</h2>
                        <div class='multiColumn'>
                            <span class='keyValueSpan'>
                                <label>Type</label>
                                <span class='jiraType'>@Model[""issueTypeName""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Status</label>
                                <span class='jiraStatus'>@Model[""statusName""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Priority</label>
                                <span class='jiraPriority'>@Model[""priorityName""]</span>
                            </span>
                        </div>
                    </div>
                     <div id='People' class='panel'>
                    
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>";
        
        string razorTemplate;
        bool isError;
        var issueDetails = new Dictionary<string, string>();
        var issue = JsonHelper.FromJSON(this.IssueStringDetails);
        
        var issueType = issue.fields["issuetype"];
        issueDetails.Add("issueTypeIconUrl", Convert.ToString(issueType.iconUrl));
        issueDetails.Add("issueTypeName", Convert.ToString(issueType.name));
        
        var project = issue.fields["project"];
        issueDetails.Add("projectIconUrl", Convert.ToString(project.avatarUrls["32x32"]));
        issueDetails.Add("issueUrl", this.BaseUrl + string.Format("browse/{0}", issue.key));
        issueDetails.Add("summary", System.Web.HttpUtility.HtmlEncode(Convert.ToString(issue.fields["summary"])));
        issueDetails.Add("issueProjectAndKey", string.Format("{0} / {1}", project.name, issue.key));
            
        var status = issue.fields["status"];
        var statusCategory = status.statusCategory;
        issueDetails.Add("statusName", Convert.ToString(status.name));
        issueDetails.Add("statusCategoryBackgroundColor", Convert.ToString(statusCategory.colorName));

        var priority = issue.fields["priority"];
        issueDetails.Add("priorityName", Convert.ToString(priority.name));
        issueDetails.Add("priorityIconUrl", Convert.ToString(priority.iconUrl));

        using (var razor = new MarvalSoftware.RazorHelper())
        {
            razorTemplate = razor.Render(jiraIssueSummaryTemplate, issueDetails, out isError);
        }

        return razorTemplate;
    }

    /// <summary>
    /// Retrieves the issue types for each JIRA project.
    /// </summary>
    /// <returns>A sorted dictionary of projects and their issue types.</returns>
    public SortedDictionary<string, string[]> GetJIRAProjectIssueTypeMapping()
    {
        HttpWebRequest httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("project"));
        string response = ProcessRequest(httpWebRequest, this.JiraCredentials);
        JArray projects = JArray.Parse(response);

        SortedDictionary<string, string[]> projectIssueTypes = new SortedDictionary<string, string[]>();
        List<Task<string>> issueTypeTasks = new List<Task<string>>();

        foreach (JToken project in projects)
        {
            //Start the task
            Task<string> task = GetProjectIssueTypesAsync(project["key"].ToString());
            task.ConfigureAwait(false);
            issueTypeTasks.Add(task);
        }

        //Wait for all issue types before sorting
        Task.WaitAll(issueTypeTasks.ToArray());

        foreach (Task<string> task in issueTypeTasks) {
            var taskResult = JObject.Parse(task.Result);
            //Filter out subtasks and Epic types and select only the issuetype's name.
            var issueTypes = taskResult["issueTypes"].Where(type => type["subtask"].ToString().Equals("False") && !(type["name"].ToString().Equals("Epic"))).Select(type => type["name"].ToString()).ToArray();

            Array.Sort(issueTypes, (x, y) => String.Compare(x, y));
            projectIssueTypes.Add(taskResult["key"].ToString(), issueTypes);
        }

        return projectIssueTypes;
    }

    /// <summary>
    /// Asyncrhonously retrieves the issue types for a given JIRA project key.
    /// </summary>
    /// <param name="projectKey"></param>
    /// <returns>A task which will evantually contain a JSON string.</returns>
    public async Task<string> GetProjectIssueTypesAsync(string projectKey)
    {
        HttpWebRequest request = BuildRequest(this.ApiBaseUrl + String.Format("project/{0}", projectKey));
        request.Headers.Add("Authorization", "Basic " + this.JiraCredentials);

        using (WebResponse response = await request.GetResponseAsync().ConfigureAwait(false))
        {
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                return await reader.ReadToEndAsync();
            }
        }
    }

    /// <summary>
    /// Gets attachment DTOs from array of attachment Ids
    /// </summary>
    /// <param name="attachmentIds"></param>
    /// <returns>A list of attachment DTOs</returns>
    public List<AttachmentViewInfo> GetAttachmentDTOs(int[] attachmentIds) {
        List<AttachmentViewInfo> attachments = new List<AttachmentViewInfo>();
        var attachmentFacade = new RequestManagementFacade();
        for (int i = 0; i < attachmentIds.Length; i++)
        {
            attachments.Add(attachmentFacade.ViewAnAttachment(attachmentIds[i]));
        }
        return attachments;
    }

    /// <summary>
    /// Link attachments to specified Jira issue.
    /// </summary>
    /// <param name="attachments"></param>
    /// <param name="issueKey"></param>
    /// <returns>The result of attempting to post the attachment data.</returns>
    public string PostAttachments(List<AttachmentViewInfo> attachments, string issueKey) {
        var boundary = string.Format("----------{0:N}", Guid.NewGuid());
        var content = new MemoryStream();
        var writer = new StreamWriter(content);
        var result = HttpStatusCode.OK.ToString();

        foreach (var attachment in attachments)
        {
            var data = attachment.Content;
            writer.WriteLine("--{0}", boundary);
            writer.WriteLine("Content-Disposition: form-data; name=\"file\"; filename=\"{0}\"", attachment.Name);
            writer.WriteLine("Content-Type: " + attachment.ContentType);
            writer.WriteLine();
            writer.Flush();
            content.Write(data, 0, data.Length);
            writer.WriteLine();
        }
        writer.WriteLine("--" + boundary + "--");
        writer.Flush();
        content.Seek(0, SeekOrigin.Begin);

        HttpWebResponse response = null;
        HttpWebRequest request = WebRequest.Create(new UriBuilder(this.ApiBaseUrl + "issue/" + issueKey + "/attachments").Uri) as HttpWebRequest;
        request.Method = "POST";
        request.ContentType = string.Format("multipart/form-data; boundary={0}", boundary);
        request.Headers.Add("Authorization", "Basic " + this.JiraCredentials);
        request.Headers.Add("X-Atlassian-Token", "nocheck");
        request.KeepAlive = true;
        request.ContentLength = content.Length;

        using (Stream requestStream = request.GetRequestStream())
        {
            content.CopyTo(requestStream);
        }

        using (response = request.GetResponse() as HttpWebResponse)
        {
            if (response.StatusCode != HttpStatusCode.OK)
            {
                result = response.StatusCode.ToString();
            }
        }
        return result;
    }

    /// <summary>
    /// Create New Jira Issue
    /// </summary>
    private JObject CreateJiraIssue()
    {
        dynamic jobject = JObject.FromObject(new
        {
            fields = new
            {
                project = new
                {
                    key = this.JiraProject
                },
                summary = this.JiraSummary,
                issuetype = new
                {
                    name = this.JiraType
                }
            }
        });
        jobject.fields[this.CustomFieldId.ToString()] = this.MsmRequestNo;

        if (!this.JiraReporter.Equals("null")) {
            dynamic reporter = new JObject();
            reporter.name = this.JiraReporter;
            jobject.fields["reporter"] = reporter;
        }

        var httpWebRequest = BuildRequest(this.ApiBaseUrl + "issue/", jobject.ToString(), "POST");
        return JObject.Parse(ProcessRequest(httpWebRequest, this.JiraCredentials));
    }

    /// <summary>
    /// Update Jira Issue
    /// </summary>
    /// <param name="value">Value to update custom field in JIRA with</param>
    /// <returns>Process Response</returns>
    private string UpdateJiraIssue(int? value)
    {
        IDictionary<string, object> body = new Dictionary<string, object>();
        IDictionary<string, object> result = new Dictionary<string, object>();
        result.Add(this.CustomFieldId, value);
        body.Add("fields", result);

        var httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("issue/{0}", JiraIssueNo), JsonHelper.ToJSON(body), "PUT");
        return ProcessRequest(httpWebRequest, this.JiraCredentials);
    }

    /// <summary>
    /// Move MSM Status
    /// </summary>
    /// <param name="httpRequest">The HttpRequest</param>
    /// <returns>Process Response</returns>
    private void MoveMsmStatus(HttpRequest httpRequest)
    {
        int requestNumber;
        var isValid = StatusValidation(httpRequest, out requestNumber);

        HttpWebRequest httpWebRequest;
        httpWebRequest = BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/requests?number={0}", requestNumber));
        var requestNumberResponse = JObject.Parse(ProcessRequest(httpWebRequest, GetEncodedCredentials(this.MSMAPIKey)));
        var requestId = (int)requestNumberResponse["collection"]["items"].First["entity"]["data"]["id"];

        httpWebRequest = BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/requests/{0}", requestId));
        var requestIdResponse = JObject.Parse(ProcessRequest(httpWebRequest, GetEncodedCredentials(this.MSMAPIKey)));
        var workflowId = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["workflow"]["id"];

        if (isValid)
        {
            //Get the next workflow states for the request...
            httpWebRequest = BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/workflows/{0}/nextStates?requestId={1}&namePredicate=equals({2})", workflowId, requestId, httpRequest.QueryString["status"]));
            var requestWorkflowResponse = JObject.Parse(ProcessRequest(httpWebRequest, GetEncodedCredentials(this.MSMAPIKey)));
            var workflowResponseItems = (IList<JToken>)requestWorkflowResponse["collection"]["items"];

            if (workflowResponseItems.Count > 0)
            {
                //Attempt to move the request state.
                dynamic msmPutRequest = new ExpandoObject();
                msmPutRequest.WorkflowStatusId = workflowResponseItems[0]["entity"]["data"]["id"];
                msmPutRequest.UpdatedOn = (DateTime)requestNumberResponse["collection"]["items"].First["entity"]["data"]["updatedOn"];

                httpWebRequest = BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/requests/{0}/states", requestId), JsonHelper.ToJSON(msmPutRequest), "POST");
                string moveStatusResponse = ProcessRequest(httpWebRequest, GetEncodedCredentials(this.MSMAPIKey));

                if (moveStatusResponse.Contains("500"))
                {
                    AddMsmNote(requestId, "JIRA status update failed: a server error occured.");
                }
            }
            else
            {
                AddMsmNote(requestId, "JIRA status update failed: " + httpRequest.QueryString["status"] + " is not a valid next state.");
            }
        }
        else
        {
            AddMsmNote(requestId, "JIRA status update failed: all linked JIRA issues must be in the same status.");
        }
    }

    /// <summary>
    /// Add MSM Note
    /// </summary>   
    private void AddMsmNote(int requestNumber, string note)
    {
        IDictionary<string, object> body = new Dictionary<string, object>();
        body.Add("id", requestNumber);
        body.Add("content", note);
        body.Add("type", "public");

        HttpWebRequest httpWebRequest;
        httpWebRequest = BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/requests/{0}/notes/", requestNumber), JsonHelper.ToJSON(body), "POST");
        ProcessRequest(httpWebRequest, GetEncodedCredentials(this.MSMAPIKey));
    }

    /// <summary>
    /// Validate before moving MSM status
    /// </summary>
    /// <param name="httpRequest">The HttpRequest</param>
    /// <returns>Boolean to determine if Valid</returns>
    private bool StatusValidation(HttpRequest httpRequest, out int requestNumber)
    {
        string json = new StreamReader(httpRequest.InputStream).ReadToEnd();
        dynamic data = JObject.Parse(json);
        requestNumber = (int)data.issue.fields[this.CustomFieldId].Value;

        if (requestNumber > 0 && httpRequest.QueryString["status"] != null)
        {
            var httpWebRequest = BuildRequest(this.ApiBaseUrl + String.Format("search?jql='{0}'={1}", this.CustomFieldName, requestNumber));
            dynamic d = JObject.Parse(ProcessRequest(httpWebRequest, this.JiraCredentials));
            foreach (var issue in d.issues)
            {
                if (issue.fields.status.name.Value != data.transition.to_status.Value)
                {
                    return false;
                }
            }

            return true;
        }
        else
        {
            return false;
        }
    }

    /// <summary>
    /// Check and return missing plugin settings
    /// </summary>
    /// <returns>Json Object containing any settings that failed the check</returns>
    private JObject PreRequisiteCheck()
    {
        var preReqs = new JObject();
        if (string.IsNullOrWhiteSpace(this.CustomFieldName))
        {
            preReqs.Add("jiraCustomFieldName", false);
        }
        if (string.IsNullOrWhiteSpace(this.CustomFieldId))
        {
            preReqs.Add("jiraCustomFieldID", false);
        }
        if (string.IsNullOrWhiteSpace(this.ApiBaseUrl))
        {
            preReqs.Add("jiraBaseUrl", false);
        }
        if (string.IsNullOrWhiteSpace(this.Username))
        {
            preReqs.Add("jiraUsername", false);
        }
        if (string.IsNullOrWhiteSpace(this.Password))
        {
            preReqs.Add("jiraPassword", false);
        }

        return preReqs;
    }

    //Generic Methods

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="uri">The uri for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private static HttpWebRequest BuildRequest(string uri = null, string body = null, string method = "GET")
    {
        var request = WebRequest.Create(new UriBuilder(uri).Uri) as HttpWebRequest;
        request.Method = method.ToUpperInvariant();
        request.ContentType = "application/json";

        if (body != null)
        {
            using (var writer = new StreamWriter(request.GetRequestStream()))
            {
                writer.Write(body);
            }
        }

        return request;
    }

    /// <summary>
    /// Proccess a HttpWebRequest
    /// </summary>
    /// <param name="request">The HttpWebRequest</param>
    /// <param name="credentials">The Credentails to use for the API</param>
    /// <returns>Process Response</returns>
    private static string ProcessRequest(HttpWebRequest request, string credentials)
    {
        try
        {
            request.Headers.Add("Authorization", "Basic " + credentials);

            HttpWebResponse response = request.GetResponse() as HttpWebResponse;
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                return reader.ReadToEnd();
            }
        }
        catch (WebException ex)
        {
            return ex.Message;
        }

    }

    /// <summary>
    /// Encodes Credentials
    /// </summary>
    /// <param name="credentials">The string to encode</param>
    /// <returns>base64 encoded string</returns>
    private string GetEncodedCredentials(string credentials)
    {
        byte[] byteCredentials = Encoding.UTF8.GetBytes(credentials);
        return Convert.ToBase64String(byteCredentials);
    }

    /// <summary>
    /// JsonHelper Functions
    /// </summary>
    internal class JsonHelper
    {
        public static string ToJSON(object obj)
        {
            return JsonConvert.SerializeObject(obj);
        }

        public static dynamic FromJSON(string json)
        {
            return JObject.Parse(json);
        }
    }
}