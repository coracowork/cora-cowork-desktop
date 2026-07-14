import * as dgram from 'node:dgram';
import * as http from 'node:http';
import * as os from 'node:os';

const SSDP_ADDR = '239.255.255.250';
const SSDP_PORT = 1900;
const SERVICE_TYPE = 'urn:schemas-upnp-org:service:WANIPConnection:1';

type UpnpDevice = {
  controlURL: string;
  serviceType: string;
};

function discoverGateway(timeout = 3000): Promise<UpnpDevice[]> {
  return new Promise((resolve) => {
    const socket = dgram.createSocket('udp4');
    const devices: UpnpDevice[] = [];
    let settled = false;

    const finish = () => {
      if (settled) return;
      settled = true;
      socket.close();
      resolve(devices);
    };

    socket.on('error', finish);

    socket.on('message', (msg) => {
      const response = msg.toString();
      const locationMatch = response.match(/^Location:\s*(.+)$/im);
      if (locationMatch) {
        parseDeviceXml(locationMatch[1].trim()).then((device) => {
          if (device) devices.push(device);
        }).catch(() => {});
      }
    });

    socket.on('listening', () => {
      try { socket.addMembership(SSDP_ADDR); } catch { /* noop */ }
      const search = [
        'M-SEARCH * HTTP/1.1',
        `HOST: ${SSDP_ADDR}:${SSDP_PORT}`,
        'MAN: "ssdp:discover"',
        `ST: ${SERVICE_TYPE}`,
        'MX: 3',
        '',
        '',
      ].join('\r\n');
      socket.send(Buffer.from(search), SSDP_PORT, SSDP_ADDR);
    });

    socket.bind(0);
    setTimeout(finish, timeout);
  });
}

async function parseDeviceXml(url: string): Promise<UpnpDevice | null> {
  return new Promise((resolve) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const serviceList = data.match(/<service[^>]*>[\s\S]*?<\/service>/gi) || [];
          for (const svc of serviceList) {
            if (svc.includes('WANIPConnection') || svc.includes('WANPPPConnection')) {
              const controlURL = extractXmlValue(svc, 'controlURL');
              const serviceType = extractXmlValue(svc, 'serviceType');
              if (controlURL) {
                const base = new URL(url);
                const fullURL = controlURL.startsWith('http')
                  ? controlURL
                  : `${base.protocol}//${base.host}${controlURL.startsWith('/') ? '' : '/'}${controlURL}`;
                return resolve({ controlURL: fullURL, serviceType: serviceType || '' });
              }
            }
          }
          resolve(null);
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

function extractXmlValue(xml: string, tag: string): string | null {
  const match = xml.match(new RegExp(`<${tag}[^>]*>([^<]*)<\\/${tag}>`));
  return match ? match[1].trim() : null;
}

function buildSoapBody(action: string, params: Record<string, string>): string {
  const entries = Object.entries(params)
    .map(([k, v]) => `<${k}>${escapeXml(v)}</${k}>`)
    .join('');
  return `<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action} xmlns:u="${SERVICE_TYPE}">
      ${entries}
    </u:${action}>
  </s:Body>
</s:Envelope>`;
}

function escapeXml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function soapRequest(controlURL: string, action: string, params: Record<string, string>): Promise<boolean> {
  return new Promise((resolve) => {
    const body = buildSoapBody(action, params);
    const url = new URL(controlURL);
    const options: http.RequestOptions = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPAction': `"${SERVICE_TYPE}#${action}"`,
        'Content-Length': Buffer.byteLength(body),
      },
      timeout: 5000,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        resolve(res.statusCode === 200);
      });
    });

    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.write(body);
    req.end();
  });
}

export async function addPortMapping(
  port: number,
  description = 'CoraCowork WebUI',
  protocol: 'TCP' | 'UDP' = 'TCP'
): Promise<boolean> {
  try {
    console.log(`[UPnP] Discovering gateway for port ${port}...`);
    const devices = await discoverGateway();
    if (devices.length === 0) {
      console.log('[UPnP] No UPnP gateway found');
      return false;
    }
    const device = devices[0];
    console.log(`[UPnP] Found gateway at ${device.controlURL}, adding port mapping...`);
    const ok = await soapRequest(device.controlURL, 'AddPortMapping', {
      NewRemoteHost: '',
      NewExternalPort: String(port),
      NewProtocol: protocol,
      NewInternalPort: String(port),
      NewInternalClient: getLanIP(),
      NewEnabled: '1',
      NewPortMappingDescription: description,
      NewLeaseDuration: '0',
    });
    console.log(`[UPnP] Port mapping ${ok ? 'added' : 'failed'}`);
    return ok;
  } catch (err) {
    console.error('[UPnP] addPortMapping error:', err);
    return false;
  }
}

export async function removePortMapping(
  port: number,
  protocol: 'TCP' | 'UDP' = 'TCP'
): Promise<boolean> {
  try {
    const devices = await discoverGateway();
    if (devices.length === 0) return false;
    const device = devices[0];
    return await soapRequest(device.controlURL, 'DeletePortMapping', {
      NewRemoteHost: '',
      NewExternalPort: String(port),
      NewProtocol: protocol,
    });
  } catch {
    return false;
  }
}

function getLanIP(): string {
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const iface of nets[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return '127.0.0.1';
}

export { getLanIP as getUpnpLanIP };
