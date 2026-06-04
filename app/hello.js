// =============================================================================
// Aplicación Node.js de ejemplo - Actividad 1 Herramientas DevOps
// Servidor HTTP simple en el puerto 3000
// Nginx actúa como reverse proxy en el puerto 80 → este servidor
// =============================================================================

const http = require('http');
const os   = require('os');

const PORT     = process.env.PORT || 3000;
const HOSTNAME = os.hostname();

const server = http.createServer((req, res) => {
  const now = new Date().toISOString();

  // Respuesta JSON con información del servidor
  const payload = {
    message:   '¡Hola desde Node.js en Azure!',
    hostname:  HOSTNAME,
    timestamp: now,
    uptime:    `${Math.floor(process.uptime())}s`,
    platform:  `${os.type()} ${os.release()}`,
    nodeVersion: process.version,
    stack:     'Node.js + PM2 + Nginx (reverse proxy)',
  };

  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload, null, 2));
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Servidor Node.js escuchando en puerto ${PORT}`);
  console.log(`Hostname: ${HOSTNAME}`);
});
