# Bloco de Notas

Aplicativo Flutter de notas com armazenamento local (SQLite), sincronização com o
Cloud Firestore, autenticação por e-mail/senha, categorias, pesquisa e arquivamento.

## Funcionalidades

- Cadastro e login de usuário (Firebase Authentication, e-mail e senha).
- Criar, listar, editar e excluir notas, no SQLite e no Firestore.
- Cada nota pertence ao usuário autenticado (campo `uid`).
- Recuperação das notas da nuvem ao entrar de novo ou em outro aparelho.
- Funciona sem internet: as notas são salvas no aparelho e enviadas depois.
- Categorias: Estudos, Trabalho, Pessoal ou categorias criadas pelo usuário.
- Filtro por categoria e pesquisa por título ou conteúdo.
- **Funcionalidade adicional: arquivamento.** Notas podem ser arquivadas e
  desarquivadas sem serem excluídas; há uma tela de notas arquivadas.
- Regras de segurança no Firestore: um usuário não acessa as notas de outro.

## Tecnologias

Flutter / Dart, `firebase_core`, `firebase_auth`, `cloud_firestore`, `sqflite`, `path`.

## Como executar

1. Instale o [Flutter](https://docs.flutter.dev/get-started/install) e rode `flutter doctor`.
2. Clone o repositório e instale as dependências:
   ```bash
   git clone <URL-DO-REPOSITORIO>
   cd bloco_de_nota_turma_B
   flutter pub get
   ```
3. Configure o Firebase (próxima seção).
4. Execute em um emulador ou aparelho:
   ```bash
   flutter run
   ```

## Configuração do Firebase

Os arquivos de configuração (`lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`)
**não ficam no repositório** (estão no `.gitignore`). Cada pessoa gera os seus:

1. Crie um projeto em <https://console.firebase.google.com>.
2. Em **Authentication > Método de login**, ative **E-mail/senha**.
3. Em **Firestore Database**, crie o banco (modo produção).
4. Em **Firestore > Regras**, cole o conteúdo do arquivo [`firestore.rules`](firestore.rules) e publique.
5. No terminal, na raiz do projeto:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Escolha o projeto criado; isso gera os arquivos de configuração.

## Arquitetura e organização dos arquivos

```
lib/
├── main.dart                      Inicializa o Firebase e escolhe a tela inicial
├── models/note.dart               Modelo Note (conversão para SQLite e Firestore)
├── database/database_helper.dart  Acesso ao SQLite
├── services/
│   ├── auth_service.dart          Login, cadastro e logout (Firebase Auth)
│   ├── firestore_service.dart     Leitura e escrita no Firestore
│   └── note_repository.dart       Une SQLite + Firestore e faz a sincronização
├── screens/                       Telas (login, cadastro, lista, formulário)
└── widgets/note_card.dart         Cartão de nota
firestore.rules                    Regras de segurança do Firestore
```

As telas só conversam com o `NoteRepository`; elas não sabem de onde o dado vem.

## Padrões de projeto

- **Singleton** (`DatabaseHelper.instance`): garante uma única conexão com o SQLite.
- **Repository** (`NoteRepository`): esconde a origem dos dados (SQLite/Firestore) das telas e concentra a lógica de sincronização.
- **Service** (`AuthService`, `FirestoreService`): isolam o acesso a cada serviço externo.
- **Offline-first / "local primeiro"**: o SQLite é a fonte lida pela interface; a nuvem é atualizada em seguida.

## Armazenamento local e integração com o Firebase

- **SQLite** (`notes.db`) tem a tabela `notes` (`id`, `uid`, `title`, `content`,
  `category`, `archived`, `synced`, `updatedAt`) e a tabela `pending_deletes`
  (exclusões que ainda não chegaram à nuvem). Toda a interface (lista, filtro,
  pesquisa) lê do SQLite.
- **Firestore** guarda as mesmas notas em `users/{uid}/notes/{idDaNota}`.
- O `id` da nota é um texto único gerado no aparelho (mesmo id nos dois lados).
- O campo `synced` existe só no aparelho e indica se a nota já foi enviada.

## Estratégia de sincronização e tratamento de erros

**Ao criar, editar, arquivar ou excluir**: grava primeiro no SQLite e depois tenta
enviar ao Firestore (limite de 8 segundos). Se falhar, a nota fica com
`synced = 0` (ícone de nuvem cortada no cartão) e o app mostra um aviso. Exclusões
que falharam vão para `pending_deletes`.

**Sincronização completa** (ao abrir a lista e ao puxar a lista para baixo):
1. envia as exclusões pendentes;
2. envia as notas com `synced = 0`;
3. baixa as notas da nuvem, e vence a de `updatedAt` mais recente;
4. remove do aparelho notas já sincronizadas que não existem mais na nuvem
   (foram excluídas em outro aparelho).

**Erros**: qualquer falha de rede, permissão ou tempo esgotado é capturada
(`try/catch`), o app não fecha, as notas continuam no aparelho e uma mensagem
informa que serão enviadas depois. A leitura usa `Source.server`, para que a
falta de internet seja detectada em vez de devolver dados em cache.

**Limitação**: em conflito de edição entre dois aparelhos vence a alteração mais
recente (não há mesclagem de campos).

## Autenticação e segurança dos dados

- Login e cadastro por e-mail/senha com Firebase Authentication; a sessão fica
  salva e o app abre direto na lista se já houver usuário logado.
- Cada nota guarda o `uid` do dono, e o SQLite só lista notas do usuário atual.
- As regras do Firestore (`firestore.rules`) permitem ler/escrever em
  `users/{userId}/notes/*` apenas quando `request.auth.uid == userId`.
- Nenhuma senha ou chave é versionada; veja "Configuração do Firebase".

## Capturas de tela

Telas do app e do console do Firebase (notas em `users/{uid}/notes`):

| Descrição | Imagem |
|---|---|
| Login | `docs/screenshots/login.png` |
| Lista de notas com categorias e pesquisa | `docs/screenshots/lista.png` |
| Notas arquivadas | `docs/screenshots/arquivadas.png` |
| Notas no Firestore (console do Firebase) | `docs/screenshots/firestore.png` |
| Regras de segurança publicadas | `docs/screenshots/regras.png` |
