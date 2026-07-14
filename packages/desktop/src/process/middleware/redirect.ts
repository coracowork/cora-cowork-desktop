// packages/desktop/src/process/middleware/redirect.ts

import type { Request, Response, NextFunction } from 'express';
import { RENDERER_URL } from '../utils/webuiConfig';

export function redirectToRenderer(req: Request, res: Response, next: NextFunction) {
  // 🔥 Ignora rotas da API
  if (req.path.startsWith('/api/')) {
    return next();
  }

  // 🔥 Ignora arquivos estáticos
  if (req.path.match(/\.(js|css|png|jpg|jpeg|gif|svg|ico|json|woff|woff2|ttf|eot|map)$/)) {
    return next();
  }

  // 🔥 Redireciona para o renderer (porta 5173)
  const targetUrl = `${RENDERER_URL}${req.path}`;
  console.log(`[Redirect] ${req.path} → ${targetUrl}`);
  return res.redirect(targetUrl);
}