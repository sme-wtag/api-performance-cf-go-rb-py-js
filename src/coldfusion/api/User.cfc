component restpath="/user" rest="true" {

    /**
     * API Endpoint to fetch user information and associated projects.
     * 
     * @param id (string, required, Path) - The user ID to fetch information for.
     * @return struct - JSON response with user information and projects or error details.
     */
    remote struct function getUser(required string id restargsource="Path") 
    httpmethod="GET" restpath="{id}" {

        // Validate the ID input
        if (len(trim(arguments.id)) == 0) {
            cfheader(statuscode="400", statustext="Bad Request");
            return { "error" = "No ID provided." };
        }

        try {
            // Fetch user information
            var userQuery = "
                SELECT 
                    id, 
                    username, 
                    email, 
                    created_at, 
                    updated_at 
                FROM 
                    benchmark.Users 
                WHERE 
                    id = ?
            ";
            var user = queryExecute(userQuery, [arguments.id], {datasource="benchmark"});

            if (user.recordCount == 0) {
                cfheader(statuscode="404", statustext="Not Found");
                return { "error" = "User not found." };
            }

            // Fetch projects associated with the user
            var projectsQuery = "
                SELECT 
                    p.id AS project_id, 
                    p.project_name, 
                    p.description, 
                    p.created_at, 
                    p.updated_at, 
                    up.role, 
                    up.assigned_at 
                FROM 
                    benchmark.User_Projects up 
                INNER JOIN 
                    benchmark.Projects p 
                ON 
                    up.project_id = p.id 
                WHERE 
                    up.user_id = ?
            ";
            var projects = queryExecute(projectsQuery, [arguments.id], {datasource="benchmark"});

            // Format the response
            var response = structNew("ordered");
            response["user"] = {
                "id" = user.id,
                "username" = user.username,
                "email" = user.email,
                "created_at" = user.created_at,
                "updated_at" = user.updated_at
            };

            response["projects"] = [];
            for (var row in projects) {
                arrayAppend(response.projects, {
                    "project_id" = row.project_id,
                    "project_name" = row.project_name,
                    "description" = row.description,
                    "created_at" = row.created_at,
                    "updated_at" = row.updated_at,
                    "role" = row.role,
                    "assigned_at" = row.assigned_at
                });
            }

            // Return the structured response
            cfheader(statuscode="200", statustext="OK");
            return response;

        } catch (any e) {
            // Log the error (optional)
            writeLog(file="api_errors", text="Error fetching user or projects: #e.message#");

            // Return a 500 Internal Server Error
            cfheader(statuscode="500", statustext="Internal Server Error");
            return { "error" = "Internal server error." };
        }
    }
}
