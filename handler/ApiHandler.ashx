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
using MarvalSoftware;
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

    private string IssueUrl { get; set; }

    //fields
    private int MsmRequestNo;
    private static readonly int second = 1;
    private static readonly int minute = 60 * second;
    private static readonly int hour = 60 * minute;
    private static readonly int day = 24 * hour;
    private static readonly int month = 30 * day;
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
                padding: 29px;
                overflow: auto;
                height: 449px;
            }            
            @@media print
            {
                #container
                {
                    overflow: visible;
                }
            }
            .content
            {
                padding-bottom: 19px;
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
            .panel .keyValueSpan .jiraAssignee
            {
                padding-left: 18px;
                background: no-repeat 0 center;
                background-image: url('@Model[""assigneeIconUrl""]');
            }            
            .panel .keyValueSpan .jiraReporter
            {
                padding-left: 18px;
                background: no-repeat 0 center;
                background-image: url('@Model[""reporterIconUrl""]');
            }
            .footer {
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                border-top: 1px solid #000;
                position: fixed; 
                bottom: 0;
                left: 0;
                right: 0;
                height: 49px;
                vertical-align: middle;
                padding-left: 30px;
                line-height: 30px;
            }
            .footer > h2
            {
                margin: 0;
                margin-top: 5px;
                padding-top: 5px;
                padding-left: 42px;
                background: no-repeat 0 center;
                background-image: url('@Model[""requestTypeIconUrl""]');
                font-size: 16px;
            }
            a 
            {
                color: #000;
                text-decoration: underline;
            }
            a:hover
            {
	            color: #F00;
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
                            <span class='keyValueSpan'>
                                <label>Resolution</label>
                                <span>@Model[""resolution""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Affects Version/s</label>
                                <span>@Model[""affectsVersions""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Fix Version/s</label>
                                <span>@Model[""fixVersions""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Component/s</label>
                                <span>@Model[""components""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Label/s</label>
                                <span>@Model[""labels""]</span>
                            </span>
                            <span class='keyValueSpan'>
                                <label>Story Points</label>
                                <span>@Model[""storyPoints""]</span>
                            </span>
                        </div>
                    </div>
                     <div id='People' class='panel'>
                        <h2>People</h2>
                        <div class='multiColumn'>
                            <span class='keyValueSpan'>
                                <label>Assignee</label>
                                @if(!string.IsNullOrEmpty(Model[""assigneeName""]))
                                {
                                <span class='jiraAssignee'>
                                    @Model[""assigneeName""]
                                </span>
                                }
                                else
                                {
                                <span>@Model[""assigneeName""]</span>
                                }
                            </span>
                            <span class='keyValueSpan'>
                                <label>Reporter</label>
                                @if(!string.IsNullOrEmpty(Model[""reporterName""]))
                                {
                                <span class='jiraReporter'>
                                    @Model[""reporterName""]
                                </span>
                                }
                                else
                                {
                                <span>@Model[""reporterName""]</span>
                                }
                            </span>
                        </div>
                    </div>
                 <div id='Dates' class='panel'>
                        <h2>Dates</h2>
                        <span class='keyValueSpan'>
                              <label>Created</label>
                              <span>@Model[""created""]</span>
                        </span>
                        <span class='keyValueSpan'>
                              <label>Updated</label>
                              <span>@Model[""updated""]</span>
                        </span>
                 </div>
                  <div id='Description' class='panel'>
                        <h2>Description</h2>
                        <span>@Model[""description""]</span>
                  </div>
                </div>
            </div>
        </div>        
        <div class='footer'>
            @if(!string.IsNullOrEmpty(Model[""msmLink""]))
            {
            <h2><a href='@Model[""msmLink""]' target='_blank' title=""@Model[""msmLinkName""]"">@Model[""msmLinkName""]</a></h2>
            }
            @if(string.IsNullOrEmpty(Model[""msmLink""]) && !string.IsNullOrEmpty(Model[""msmLinkName""]))
            {
            <h2 title=""@Model[""msmLinkName""]"">@Model[""msmLinkName""]</h2>
            }
        </div>
    </body>
</html>";
        
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
        this.IssueUrl = httpRequest.Params["issueUrl"] ?? string.Empty;
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
                httpWebRequest = BuildRequest(this.IssueUrl);
                context.Response.Write(this.BuildPreview(ProcessRequest(httpWebRequest, this.JiraCredentials)));
                break;
        }
    }

    /// <summary>
    /// Build a summary preview of the jira issue to display in MSM
    /// </summary>
    /// <returns></returns>
    private string BuildPreview(string issueString)
    {
        if (string.IsNullOrEmpty(issueString)) return string.Empty;

        var issueDetails = PopulateIssueDetails(issueString);

        bool isError;
        string razorTemplate = string.Empty;
        using (var razor = new MarvalSoftware.RazorHelper())
        {
            razorTemplate = razor.Render(jiraIssueSummaryTemplate, issueDetails, out isError);
        }

        return razorTemplate;
    }

    private Dictionary<String, String> PopulateIssueDetails(String issueString)
    {
        var issue = JsonHelper.FromJSON(issueString);
        var issueDetails = new Dictionary<string, string>();

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

        var resolution = issue.fields["resolution"];
        issueDetails.Add("resolution", resolution != null ? Convert.ToString(resolution.name) : "Unresolved");

        var affectedVersions = (JArray)issue.fields["versions"];
        issueDetails.Add("affectsVersions", affectedVersions.Count() > 0 ? string.Join(",", affectedVersions.Select(av => ((dynamic)av).name)) : "None");

        var fixVersions = (JArray)issue.fields["fixVersions"];
        issueDetails.Add("fixVersions", fixVersions.Count() > 0 ? string.Join(",", fixVersions.Select(fv => ((dynamic)fv).name)) : "None");

        var components = (JArray)issue.fields["components"];
        issueDetails.Add("components", components.Count() > 0 ? string.Join(",", components.Select(c => ((dynamic)c).name)) : "None");

        var labels = (JArray)issue.fields["labels"];
        issueDetails.Add("labels", labels.Count() > 0 ? string.Join(",", labels.Select(c => ((dynamic)c).name)) : "None");
        issueDetails.Add("storyPoints", Convert.ToString(issue.fields["aggregatetimeestimate"]));

        var assignee = issue.fields["assignee"];
        issueDetails.Add("assigneeName", assignee != null ? Convert.ToString(assignee.displayName) : "Unassigned");
        issueDetails.Add("assigneeIconUrl", assignee != null ? Convert.ToString(assignee.avatarUrls["16x16"]) : string.Empty);

        var reporter = issue.fields["reporter"];
        issueDetails.Add("reporterName", reporter != null ? Convert.ToString(reporter.displayName) : string.Empty);
        issueDetails.Add("reporterIconUrl", reporter != null ? Convert.ToString(reporter.avatarUrls["16x16"]) : string.Empty);

        DateTime createdDate;
        issueDetails.Add("created", string.Empty);
        if (DateTime.TryParse(Convert.ToString(issue.fields["created"]), out createdDate))
        {
            issueDetails["created"] = ApiHandler.GetRelativeTime(createdDate);
        }

        DateTime updatedDate;
        issueDetails.Add("updated", string.Empty);
        if (DateTime.TryParse(Convert.ToString(issue.fields["updated"]), out updatedDate))
        {
            issueDetails["updated"] = ApiHandler.GetRelativeTime(updatedDate);
        }

        issueDetails.Add("description", ApiHandler.ProcessJiraDescription(issue));
        issueDetails.Add("msmLink", string.Empty);
        issueDetails.Add("msmLinkName", string.Empty);
        issueDetails.Add("requestTypeIconUrl", string.Empty);

        if (issue.fields[this.CustomFieldId] != null)
        {
            var requestId = Convert.ToString(issue.fields[this.CustomFieldId]);
            var msmResponse = string.Empty;

            try
            {
                msmResponse = ApiHandler.ProcessRequest(ApiHandler.BuildRequest(this.MSMBaseUrl + String.Format("/api/serviceDesk/operational/requests/{0}", requestId)), this.GetEncodedCredentials(this.MSMAPIKey));
                var requestResponse = JObject.Parse(msmResponse);
                issueDetails["msmLinkName"] = string.Format("{0}-{1} {2}", requestResponse["entity"]["data"]["type"]["acronym"], requestResponse["entity"]["data"]["number"], requestResponse["entity"]["data"]["description"]);
                issueDetails["msmLink"] = string.Format("{0}{1}/RFP/Forms/Request.aspx?id={2}", HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath, requestId);
                issueDetails["requestTypeIconUrl"] = this.GetRequestBaseTypeIconUrl(Convert.ToInt32(requestResponse["entity"]["data"]["type"]["baseTypeId"]));
            }
            catch(Exception ex)
            {
                issueDetails["msmLinkName"] = string.Format("An Error occured: {0}, The MSM API Response was: {1}", ex.Message, msmResponse);
            }
        }

        return issueDetails;
    }

    private static string ProcessJiraDescription(dynamic issue)
    {
        var description = Convert.ToString(issue.fields["description"]);
        if (string.IsNullOrEmpty(description)) return description;

        description = WikiNetParser.WikiProvider.ConvertToHtml(description);
        foreach (System.Text.RegularExpressions.Match match in System.Text.RegularExpressions.Regex.Matches(description, "!(.*)!"))
        {
            if (match.Groups.Count > 1)
            {
                var filename = match.Groups[1].Value;
                var attachment = (dynamic)((JArray)issue.fields["attachment"]).FirstOrDefault(att => string.Equals(Convert.ToString(((dynamic)att).filename), filename, StringComparison.OrdinalIgnoreCase));
                if (attachment != null)
                {
                    description = System.Text.RegularExpressions.Regex.Replace(description, match.Groups[0].Value, string.Format("<img src='{0}' title='{1}'/>", Convert.ToString(attachment.content), filename));
                }
            }
        }

        return description;
    }

    private string GetRequestBaseTypeIconUrl(int requestBaseType)
    {
        var baseRequestType = (MarvalSoftware.ServiceDesk.ServiceSupport.BaseRequestTypes)requestBaseType;
        string icon = baseRequestType.ToString().ToLower();
        if (icon == "changerequest")
        {
            icon = "change";
        }
        return string.Format("{0}{1}/Assets/Skins/{2}/Icons/{3}_32.png", HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath, MarvalSoftware.UI.WebUI.Style.StyleSheetManager.Skin, icon);
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

    private static string GetRelativeTime(DateTime date)
    {
        var localDateTime = TimezoneHelper.ToLocalTime(date);
        var ts = new TimeSpan(DateTime.UtcNow.Ticks - date.Ticks);
        double delta = Math.Abs(ts.TotalSeconds);
        var localTimeOfDay = localDateTime.ToShortTimeString();
        if (delta < 1 * minute)
        {
            return ts.Seconds == 1 ? "1 second ago" : "A few seconds ago";
        }

        if (delta < 2 * minute)
        {
            return "1 minute ago";
        }

        if (delta < 45 * minute)
        {
            return string.Format("{0} minutes ago", ts.Minutes);
        }

        if (delta < 90 * minute)
        {
            return "1 hour ago";
        }

        if (delta < 24 * hour)
        {
            return string.Format("{0} hours ago", ts.Hours);
        }

        if (delta < 48 * hour)
        {
            return string.Format("Yesterday {0}", localTimeOfDay);
        }

        if (delta < 7 * day)
        {
            return string.Format("{0} {1}", localDateTime.DayOfWeek, localTimeOfDay);
        }

        return localDateTime.ToString();
    }
}