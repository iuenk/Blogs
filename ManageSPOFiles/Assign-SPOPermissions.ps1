# Permissions can be any of the following: Read, Write, Manage, FullControl.
# A seperate app registration with Microsoft Graph API Sites.FullControl.All is necessary for this and should only be used by the SPO team.

$Body = @{
    "roles" = @("write")
    "grantedToIdentities" = @(
        @{
            "application" = @{
                "id" = "application client id"
                "displayName" = "application displayname"
            }
        }
    )
} | convertto-json -Depth 100


$uri = "https://graph.microsoft.com/v1.0/sites/$SiteId/permissions"
Invoke-RestMethod -Uri $Uri -Headers $($global:authHeader) -Method POST -Body $Body -ContentType 'application/json'