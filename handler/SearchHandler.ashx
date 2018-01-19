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

    private string SearchText { get; set; }

    private int MaximumNumberOfResults { get; set; }

    /// <summary>
    /// Handle Request
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        this.ProcessParamaters(context.Request);
        var httpWebRequest = this.BuildRequest(this.ApiBaseUrl + String.Format("search?jql=issue={0}", this.SearchText));
        context.Response.Write(this.ProcessRequest(httpWebRequest, this.JiraCredentials));
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
        this.SearchText = httpRequest.Params["searchText"] ?? string.Empty;
        int maxResults;
        int.TryParse(httpRequest.Params["issueSummary"] ?? string.Empty, out maxResults);
        this.MaximumNumberOfResults = maxResults;
    }

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="uri">The uri for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private HttpWebRequest BuildRequest(string uri = null, string body = null, string method = "GET")
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
    private string ProcessRequest(HttpWebRequest request, string credentials)
    {
        var issueList = new List<object>();

        try
        {
            request.Headers.Add("Authorization", "Basic " + credentials);

            HttpWebResponse response = request.GetResponse() as HttpWebResponse;
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                var searchResponse = JsonHelper.FromJSON(reader.ReadToEnd());
                var foundIssues = (JArray)searchResponse.issues;

                foreach (dynamic issue in foundIssues)
                {
                    issueList.Add(new
                    {
                        Url = this.BaseUrl + string.Format("browse/{0}", issue.key),
                        Text = string.Format("{0} {1}", issue.key, issue.fields["description"]),
                        PreviewUrl = Convert.ToString(issue.self),
                        ExternalIconUrl = string.Format("{0}{1}", this.PluginBaseUrl, "img/jira_16.png")
                    });
                }
            }
        }
        catch (WebException ex)
        {
            using (StreamReader reader = new StreamReader(ex.Response.GetResponseStream()))
            {
                return reader.ReadToEnd();
            }
        }

        return JsonHelper.ToJSON(issueList);
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