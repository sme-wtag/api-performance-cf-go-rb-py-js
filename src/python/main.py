from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pymysql
from pymysql.cursors import DictCursor
from config import db_config

app = FastAPI()

# Utility function to query the database
def query_database(query, params=None):
    try:
        conn = pymysql.connect(**db_config, cursorclass=DictCursor)
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            result = cursor.fetchall()
        conn.close()
        return result
    except Exception as e:
        print("Database error:", e)
        raise

# API to get user information with projects
@app.get("/api/user/{user_id}")
async def get_user_projects(user_id: int):
    try:
        # Fetch user information
        user_query = "SELECT id, username, email, created_at, updated_at FROM users WHERE id = %s"
        user = query_database(user_query, (user_id,))

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Fetch projects associated with the user
        projects_query = """
            SELECT 
                p.id AS project_id,
                p.project_name,
                p.description,
                p.created_at,
                p.updated_at,
                up.role,
                up.assigned_at
            FROM user_projects up
            INNER JOIN projects p ON up.project_id = p.id
            WHERE up.user_id = %s
        """
        projects = query_database(projects_query, (user_id,))

        # Format the response
        response = {
            "user": user[0],
            "projects": projects
        }

        return response
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail="Internal server error")
