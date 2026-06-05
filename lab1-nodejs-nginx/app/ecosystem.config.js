// =============================================================================
// PM2 Ecosystem Config - Gestor de procesos para Node.js
// Garantiza que la app se reinicie automáticamente si falla
// =============================================================================

module.exports = {
  apps: [
    {
      name:         'myapp',
      script:       '/opt/myapp/hello.js',
      instances:    1,
      autorestart:  true,
      watch:        false,
      max_memory_restart: '256M',
      env: {
        NODE_ENV: 'production',
        PORT:     3000,
      },
      // Log files
      out_file:  '/var/log/pm2/myapp-out.log',
      error_file: '/var/log/pm2/myapp-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    },
  ],
};
