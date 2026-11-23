// Service worker do Kaerith (substitui o que o Godot gera; o publicar.bat copia este por cima e troca a versão).
// Pedido do João (2026-11-22): a versão nova tem que chegar sem quebrar o jogo offline.
//
// Como funciona:
//  - Cada publicação tem uma VERSAO nova. O navegador vê que este arquivo mudou e instala o worker novo em segundo
//    plano, baixando TUDO do jogo (inclusive index.wasm e index.pck) para um cache novo. Arquivo que não mudou
//    (o servidor responde 304 pelo ETag) é copiado do cache antigo, sem baixar de novo.
//  - Se a instalação falhar no meio (sem internet), nada muda: o jogo continua com a versão antiga, completa.
//  - Enquanto o jogo está aberto, a versão antiga continua valendo. A página (kaerith_shell.html) mostra o aviso
//    "Nova versão" e, ao tocar, troca; ou troca sozinha na próxima vez que o jogo abrir.
//  - O jogo sempre abre do cache (funciona offline). Abrir pelo endereço "/" ou com ?algo também usa o cache.
const VERSAO = '__VERSAO__';
const PREFIXO = 'kaerith-';
const CACHE = PREFIXO + VERSAO;
const OBRIGATORIOS = ['index.html', 'index.js', 'index.wasm', 'index.pck', 'index.offline.html',
	'index.audio.worklet.js', 'index.audio.position.worklet.js'];
const OPCIONAIS = ['index.manifest.json', 'index.icon.png', 'index.apple-touch-icon.png', 'index.png',
	'index.144x144.png', 'index.180x180.png', 'index.512x512.png'];
const ARQUIVOS = OBRIGATORIOS.concat(OPCIONAIS);

// peso de cada arquivo na barra de "Baixando atualização" (o motor e o pacote são quase tudo)
function peso(nome) {
	return nome === 'index.wasm' ? 75 : (nome === 'index.pck' ? 18 : 0.5);
}
const PESO_TOTAL = ARQUIVOS.reduce((t, n) => t + peso(n), 0);

async function avisar(p) {
	try {
		const todos = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
		todos.forEach((c) => c.postMessage({ tipo: 'kaerith-progresso', p: Math.min(1, p) }));
	} catch (e) { /* nada */ }
}

// lê a resposta aos pedaços para contar o progresso e devolve uma cópia igual para o cache
// (o Firebase manda o wasm comprimido e sem Content-Length: aí a conta usa o tamanho da versão anterior
// ou uma estimativa; o que importa para a tela é a barra andar)
const ESTIMADO = { 'index.wasm': 38000000, 'index.pck': 9000000 };
async function lerContando(r, antes, nome, tamAntigo) {
	const comprimido = !!r.headers.get('Content-Encoding');
	const total = (!comprimido && Number(r.headers.get('Content-Length'))) || tamAntigo || ESTIMADO[nome] || 0;
	if (!r.body || !total) {
		return r;
	}
	const leitor = r.body.getReader();
	const partes = [];
	let lido = 0;
	let ultimo = 0;
	for (;;) {
		const { done, value } = await leitor.read();
		if (done) {
			break;
		}
		partes.push(value);
		lido += value.length;
		const agora = Date.now();
		if (agora - ultimo > 250) {
			ultimo = agora;
			avisar((antes + peso(nome) * Math.min(0.99, lido / total)) / PESO_TOTAL);
		}
	}
	return new Response(new Blob(partes), { status: r.status, statusText: r.statusText, headers: r.headers });
}

function endereco(nome) {
	return new URL(nome, self.registration.scope).href;
}

// caches de versões anteriores (os nossos e os do service worker do Godot)
async function cachesAntigos() {
	const nomes = await caches.keys();
	return nomes.filter((k) => k !== CACHE && (k.startsWith(PREFIXO) || k.indexOf('-sw-cache-') >= 0));
}

async function procurarAntigo(antigos, url) {
	for (const k of antigos) {
		const r = await (await caches.open(k)).match(url, { ignoreSearch: true });
		if (r) {
			return r;
		}
	}
	return null;
}

self.addEventListener('install', (event) => {
	event.waitUntil((async () => {
		const novo = await caches.open(CACHE);
		const antigos = await cachesAntigos();
		let feito = 0;
		for (const nome of ARQUIVOS) {
			const antes = feito;
			feito += peso(nome);
			avisar(antes / PESO_TOTAL);
			const url = endereco(nome);
			const antigo = await procurarAntigo(antigos, url);
			const cab = {};
			const etag = antigo ? antigo.headers.get('ETag') : null;
			if (etag) {
				cab['If-None-Match'] = etag;
			}
			let r;
			try {
				r = await fetch(url, { cache: 'no-store', headers: cab });
			} catch (e) {
				if (OPCIONAIS.includes(nome)) {
					continue;
				}
				throw e;                       // sem internet: a instalação falha e a versão antiga continua
			}
			if (r.status === 304 && antigo) {
				await novo.put(url, antigo);   // não mudou: reaproveita (não gasta a cota do Firebase)
				continue;
			}
			if (!r.ok) {
				if (OPCIONAIS.includes(nome)) {
					continue;
				}
				throw new Error('Kaerith: falhou ' + nome + ' (' + r.status + ')');
			}
			let tamAntigo = 0;
			try {
				tamAntigo = antigo ? (await antigo.clone().blob()).size : 0;
			} catch (e) { /* nada */ }
			await novo.put(url, await lerContando(r, antes, nome, tamAntigo));
		}
		avisar(1);
		// ainda existe o cache do service worker do Godot (antes era o dele, que só troca quando TODAS as abas fecham;
		// no Safari a aba fica guardada e a troca nunca vinha): assume logo, sem esperar
		if (antigos.some((k) => k.indexOf('-sw-cache-') >= 0)) {
			await self.skipWaiting();
		}
	})().catch(async (e) => {
		await caches.delete(CACHE);            // não deixa um cache pela metade
		throw e;
	}));
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const antigos = await cachesAntigos();
		const vinhaDoGodot = antigos.some((k) => k.indexOf('-sw-cache-') >= 0);
		for (const k of antigos) {
			await caches.delete(k);
		}
		await self.clients.claim();
		if (vinhaDoGodot) {
			// as abas abertas ainda rodam a página antiga do Godot (sem o aviso de versão nova): recarrega uma vez
			try {
				for (const c of await self.clients.matchAll({ type: 'window' })) {
					c.navigate(c.url).catch(() => {});
				}
			} catch (e) { /* navegador sem navigate(): troca na próxima abertura */ }
		}
	})());
});

self.addEventListener('fetch', (event) => {
	const req = event.request;
	if (req.method !== 'GET') {
		return;
	}
	const url = new URL(req.url);
	const escopo = new URL(self.registration.scope);
	if (url.origin !== escopo.origin || !url.pathname.startsWith(escopo.pathname)) {
		return;
	}
	let nome = url.pathname.slice(escopo.pathname.length);
	if (req.mode === 'navigate') {
		if (nome !== '' && nome !== 'index.html') {
			return;                            // privacidade.html, suporte.html etc. vêm da rede
		}
		nome = 'index.html';
	}
	if (!ARQUIVOS.includes(nome)) {
		return;
	}
	event.respondWith((async () => {
		const cache = await caches.open(CACHE);
		const guardado = await cache.match(endereco(nome));
		if (guardado) {
			return guardado;
		}
		try {
			return await fetch(req);
		} catch (e) {
			const offline = req.mode === 'navigate' ? await cache.match(endereco('index.offline.html')) : null;
			return offline || Response.error();
		}
	})());
});

self.addEventListener('message', (event) => {
	if (event.origin !== self.location.origin) {
		return;
	}
	// 'atualizar' (página do Kaerith) ou 'update'/'claim' (nomes do Godot): a versão nova assume
	if (event.data === 'atualizar' || event.data === 'update' || event.data === 'claim') {
		self.skipWaiting();
	}
});
