const express = require('express');
const mysql = require('mysql');
const config = require('./config');

// Create a connection pool
const pool = mysql.createPool(config.db);

const app = express();
const PORT = 3000;

// Utility function to query the database
const queryDatabase = (sql, params = []) => {
    return new Promise((resolve, reject) => {
        pool.getConnection((err, connection) => {
            if (err) {
                return reject(err);
            }
            connection.query(sql, params, (error, results) => {
                connection.release();
                if (error) {
                    return reject(error);
                }
                resolve(results);
            });
        });
    });
};

// API to get user information with projects
app.get('/api/user/:userId', async (req, res) => {
    const { userId } = req.params;

    try {
        // Fetch user information
        const userQuery = `SELECT id, username, email, created_at, updated_at FROM users WHERE id = ?`;
        const user = await queryDatabase(userQuery, [userId]);

        if (user.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Fetch projects associated with the user
        const projectsQuery = `
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
            WHERE up.user_id = ?
        `;
        const projects = await queryDatabase(projectsQuery, [userId]);

        // Format the response
        const response = {
            user: user[0],
            projects: projects
        };

        res.status(200).json(response);
    } catch (error) {
        console.error('Database error:', error.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Start the server
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});
