# Bloco de Notas

Aplicativo Flutter de bloco de notas com **armazenamento local (SQLite)**
sincronizado com o **Cloud Firestore**, autenticação por e-mail e senha,
organização por **categorias**, **pesquisa** por título e conteúdo e
**lixeira com recuperação**.

## Objetivo

Permitir que a pessoa escreva e organize suas notas no aparelho, com acesso
imediato e funcionamento sem internet, e ao mesmo tempo mantenha esses dados
salvos na nuvem — de modo que, ao entrar novamente ou instalar o aplicativo
em outro aparelho, as notas voltem exatamente como estavam.

---

## Funcionalidades implementadas

### Notas
- Cadastrar, consultar, editar e excluir notas.
- Cada operação grava **no SQLite e no Cloud Firestore**.
- Toda nota é associada ao `uid` do usuário autenticado.
- Recuperação das notas da nuvem ao entrar novamente ou em outra instalação.

### Categorias
- Criar, renomear, trocar a cor e excluir categorias.
- Associar uma categoria a cada nota (ou deixá-la sem categoria).
- Filtrar a lista por categoria, com a contagem de notas em cada chip.
- Excluir uma categoria **não exclui as notas**: elas voltam a ficar sem
  categoria.
- Atalho "usar categorias sugeridas" (Estudos, Trabalho, Pessoal, Ideias).

### Pesquisa
- Pesquisa por **título e conteúdo** ao mesmo tempo.
- Ignora maiúsculas **e acentos**: `ANIVERSÁRIO`, `Aniversário` e
  `aniversario` encontram a mesma nota.
- Roda no SQLite, sobre tudo que já foi baixado da nuvem, então funciona
  igual online e offline.

### Funcionalidade adicional — Lixeira com recuperação
- Excluir uma nota na listagem **não apaga nada**: ela vai para a lixeira.
- A lixeira mostra as notas excluídas e a data da exclusão.
- É possível **restaurar** uma nota ou **excluí-la definitivamente**
  (aí sim ela é removida do aparelho e do Firebase).
- Botão "Esvaziar" para apagar tudo de uma vez, com confirmação.
- A lixeira é um **campo sincronizado** (`isDeleted`), não a ausência do
  documento: uma nota mandada para a lixeira em um aparelho continua na
  lixeira em qualquer outro.
- A listagem ainda oferece **"Desfazer"** logo após a exclusão.

### Extras
- **Ordenação** por atualização, por criação (crescente/decrescente) e por
  título.
- **Faixa de estado da sincronização**, com aviso quando há notas na fila
  esperando conexão e botão "tentar de novo".
- Ícone de nuvem cortada no cartão da nota que ainda não subiu.
- "Arraste para atualizar" na lista, que força uma sincronização.
- Sessão restaurada automaticamente ao reabrir o aplicativo.

---

## Tecnologias e dependências

| Pacote | Versão | Para que é usado |
|---|---|---|
| `flutter` | SDK `^3.12.2` | Framework do aplicativo |
| `firebase_core` | `^4.15.0` | Inicialização do Firebase |
| `firebase_auth` | `^6.7.0` | Login e cadastro por e-mail e senha |
| `cloud_firestore` | `^6.10.2` | Armazenamento das notas na nuvem |
| `sqflite` | `^2.4.4+1` | Banco de dados local (SQLite) |
| `path` | `^1.9.1` | Monta o caminho do arquivo do banco |
| `uuid` | `^4.6.0` | Gera o ID compartilhado entre local e nuvem |
| `intl` | `^0.20.3` | Formatação de datas em português |

Dependências de desenvolvimento:

| Pacote | Para que é usado |
|---|---|
| `flutter_test` | Execução dos testes |
| `flutter_lints` | Análise estática |
| `sqflite_common_ffi` | Roda o SQLite real nos testes, fora do aparelho |
| `fake_cloud_firestore` | Firestore falso para testar a sincronização |

---

## Como executar

### Pré-requisitos
- Flutter SDK 3.12.2 ou superior (`flutter --version`).
- Um emulador Android, um simulador iOS ou um aparelho conectado.
- Uma conta no [Firebase](https://console.firebase.google.com).

### Passos

```bash
git clone https://github.com/FelipeIsmael-dev/bloco_de_nota_turma_B.git
cd bloco_de_nota_turma_B
flutter pub get
flutter run
```

### Rodar os testes

```bash
flutter test
```

### Conferir a análise estática

```bash
flutter analyze
```

---

## Configuração do Firebase

O repositório já vem configurado para o projeto Firebase usado em aula
(`bdbloco`). Para apontar o aplicativo para **outro** projeto, siga os
passos abaixo.

### 1. Criar o projeto

No [console do Firebase](https://console.firebase.google.com), crie um
projeto novo.

### 2. Ativar a autenticação

Em **Authentication → Sign-in method**, habilite **E-mail/senha**.

### 3. Criar o banco Firestore

Em **Firestore Database → Criar banco de dados**, escolha a região e comece
em **modo de produção** (as regras deste repositório serão publicadas no
passo 5).

### 4. Gerar os arquivos de configuração

```bash
npm install -g firebase-tools
firebase login

dart pub global activate flutterfire_cli
flutterfire configure
```

O comando gera/atualiza:

- `lib/firebase_options.dart` — chaves públicas de cada plataforma;
- `android/app/google-services.json` — configuração do app Android.

> **Sobre segurança:** esses dois arquivos contêm apenas **identificadores
> públicos de cliente** (project ID, app ID e a chave de API do cliente).
> Eles não são segredos: qualquer pessoa consegue extraí-los de um APK
> publicado. Quem protege os dados é a autenticação somada às **regras de
> segurança** do passo 5 — por isso elas não podem ser deixadas em modo de
> teste. O repositório **não contém** nenhuma chave de conta de serviço,
> senha ou credencial de administrador, e nenhum arquivo desses deve ser
> adicionado.

### 5. Publicar as regras de segurança

As regras estão versionadas em [`firestore.rules`](firestore.rules):

```bash
firebase deploy --only firestore:rules
```

---

## Arquitetura e organização dos arquivos

O projeto é dividido em camadas. Cada uma só conhece a camada de baixo, o
que mantém a regra de sincronização num lugar só.

```text
┌────────────────────────────────────────────┐
│  screens/ + widgets/   (interface)         │
└───────────────────┬────────────────────────┘
                    │  só fala com o repositório
┌───────────────────▼────────────────────────┐
│  repositories/   NoteRepository            │
│  decide o que vai para onde e quem vence   │
│  num conflito                              │
└──────────┬───────────────────┬─────────────┘
           │                   │
┌──────────▼─────────┐ ┌───────▼─────────────┐
│ database/          │ │ services/           │
│ DatabaseHelper     │ │ FirestoreService    │
│ (SQLite)           │ │ AuthService         │
└────────────────────┘ └─────────────────────┘
```

```text
lib/
├── main.dart                        Inicializa o Firebase, tema e AuthGate
├── firebase_options.dart            Gerado pelo FlutterFire CLI
│
├── models/
│   ├── note.dart                    Nota + conversores local/remoto
│   ├── note_category.dart           Categoria + conversores local/remoto
│   ├── note_sort.dart               Critérios de ordenação (ORDER BY)
│   └── sync_status.dart             synced / pendingUpsert / pendingDelete
│
├── database/
│   └── database_helper.dart         SQLite: esquema, migração e consultas
│
├── services/
│   ├── auth_service.dart            Firebase Auth + mensagens de erro
│   └── firestore_service.dart       Cloud Firestore + CloudException
│
├── repositories/
│   ├── note_repository.dart         Coordena SQLite <-> Firestore
│   └── sync_outcome.dart            Resultado de uma sincronização
│
├── screens/
│   ├── login_page.dart              Entrar
│   ├── register_page.dart           Criar conta
│   ├── notes_page.dart              Lista, pesquisa, filtro e ordenação
│   ├── note_form_page.dart          Criar/editar nota e escolher categoria
│   ├── categories_page.dart         Gerenciar categorias
│   └── trash_page.dart              Lixeira com recuperação
│
├── widgets/
│   ├── note_card.dart               Cartão da nota
│   └── sync_banner.dart             Faixa de estado da sincronização
│
└── utils/
    ├── app_date_format.dart         "Hoje às 14:32"
    └── text_normalizer.dart         Normalização usada pela pesquisa

test/
└── note_repository_test.dart        Testes da integração local <-> nuvem

firestore.rules                      Regras de segurança do Firestore
```

---

## Padrões de projeto adotados

### Singleton — `DatabaseHelper`

`DatabaseHelper.instance` é a única instância da classe, e ela mantém uma
única conexão aberta com o arquivo `notes.db`.

**Por quê:** o SQLite trava o arquivo durante uma escrita. Se cada tela
abrisse a própria conexão, duas gravações simultâneas poderiam resultar em
`database is locked`. Com uma instância só, todas as operações passam pela
mesma conexão.

**Onde:** `lib/database/database_helper.dart`.

### Repository — `NoteRepository`

As telas chamam `repository.saveNote(...)` e não sabem se o dado foi parar
no SQLite, no Firestore ou nos dois.

**Por quê:** a decisão "grava local, tenta a nuvem, se falhar deixa
pendente" aparece em toda operação de escrita. Deixá-la nas telas
significaria repetir — e esquecer — essa regra em cada botão. Concentrada no
repositório, a regra existe uma vez só.

**Onde:** `lib/repositories/note_repository.dart`.

### Data Mapper — `toLocalMap` / `fromLocalMap` / `toRemoteMap` / `fromRemoteMap`

Cada modelo sabe se converter para os dois formatos de armazenamento.

**Por quê:** os dois bancos guardam a mesma nota de formas diferentes —
no SQLite `is_deleted` é `0`/`1` e as colunas usam `snake_case`; no Firestore
`isDeleted` é um booleano e os campos usam `camelCase`. Com os conversores no
modelo, nem o banco nem o Firestore precisam conhecer o formato do outro.

**Onde:** `lib/models/note.dart` e `lib/models/note_category.dart`.

### Injeção de dependência por construtor

`NoteRepository({DatabaseHelper? local, FirestoreService? cloud})` e
`FirestoreService({FirebaseFirestore? firestore})` aceitam substitutos.

**Por quê:** é o que torna os testes possíveis sem um projeto Firebase real.
Os testes injetam um `FakeFirebaseFirestore` e um `FirestoreService` que
sempre falha, para simular a falta de internet.

**Onde:** construtores de `NoteRepository` e `FirestoreService`.

### Column Transform (coluna derivada) — `search_text`

Além de `title` e `content`, a tabela guarda `search_text`: o texto dos dois
campos em minúsculas e sem acentos, gerado na hora de gravar.

**Por quê:** o `LIKE ... COLLATE NOCASE` do SQLite só ignora maiúsculas de
letras ASCII, então `ANIVERSÁRIO` **não** encontrava `Aniversário`. Com a
coluna normalizada, o termo digitado passa pela mesma transformação e a
comparação é feita entre dois textos no mesmo formato.

**Onde:** `lib/utils/text_normalizer.dart` e a consulta `getNotes` em
`lib/database/database_helper.dart`.

---

## Armazenamento local (SQLite)

Arquivo: `notes.db`. Esquema na versão 2:

**Tabela `notes`**

| Coluna | Tipo | Função |
|---|---|---|
| `local_id` | INTEGER PK | Chave primária do SQLite |
| `id` | TEXT UNIQUE | **UUID compartilhado com o Firestore** |
| `uid` | TEXT | Dono da nota (UID do Firebase Auth) |
| `title` | TEXT | Título |
| `content` | TEXT | Conteúdo |
| `search_text` | TEXT | Título + conteúdo normalizados (pesquisa) |
| `category_id` | TEXT | FK para `categories.id` (`ON DELETE SET NULL`) |
| `created_at` | TEXT | Criação, ISO 8601 em UTC |
| `updated_at` | TEXT | Última alteração, ISO 8601 em UTC |
| `is_deleted` | INTEGER | `1` quando está na lixeira |
| `deleted_at` | TEXT | Quando foi para a lixeira |
| `sync_status` | INTEGER | `0` sincronizado, `1` a enviar, `2` a excluir |

**Tabela `categories`** segue o mesmo desenho (`id`, `uid`, `name`, `color`,
datas e `sync_status`).

Índices: `(uid, is_deleted)` para a listagem, `sync_status` para a fila de
pendências e `(uid, is_deleted)` nas categorias.

### Migração da versão 1

A versão 1 (`id`, `uid`, `title`, `content`, `date`) não tinha UUID nem
datas comparáveis. Quem já usava o aplicativo **não perde as notas**: o
`onUpgrade` copia cada linha antiga para a nova tabela, gerando um UUID,
convertendo o texto `dd/MM/yyyy HH:mm` para ISO 8601 e marcando a nota como
**pendente**, para que o primeiro login já a envie para o Firestore.

---

## Integração com o Firebase

### Estrutura na nuvem

```text
users/{uid}/notes/{noteId}
users/{uid}/categories/{categoryId}
```

Os dados de cada pessoa ficam **dentro** do documento dela. Essa escolha é o
que torna as regras de segurança simples e difíceis de errar: basta comparar
o `{uid}` do caminho com o do token autenticado.

Documento de uma nota:

```json
{
  "uid": "A1b2C3...",
  "title": "Prova de BD",
  "content": "Estudar normalização",
  "categoryId": "9f8e7d6c-...",
  "createdAt": "2026-10-28T13:04:11.000Z",
  "updatedAt": "2026-10-29T18:22:40.000Z",
  "isDeleted": false,
  "deletedAt": null
}
```

### A chave da integração: o UUID compartilhado

O `id` da nota é um **UUID gerado no aplicativo** e usado ao mesmo tempo como
chave única na tabela `notes` e como **ID do documento** no Firestore.

Sem isso não existe sincronização: o `AUTOINCREMENT` do SQLite daria IDs
diferentes em cada aparelho, e não haveria como saber se um documento da
nuvem corresponde a uma linha local ou é uma nota nova. É esse campo que
permite dizer "este documento e esta linha são a mesma nota".

---

## Estratégia de sincronização

### Offline-first com fila de pendências

1. **Toda escrita vai primeiro para o SQLite**, marcada como
   `pendingUpsert` ou `pendingDelete`. Como o banco local não depende de
   rede, a ação do usuário nunca falha.
2. Em seguida o aplicativo tenta replicar no Firestore. Deu certo, a linha
   vira `synced`. Falhou, ela **continua pendente** e será reenviada depois.
3. `synchronize()` faz o ciclo completo e é chamado ao abrir a lista de
   notas (login ou instalação nova), no "arraste para atualizar" e no botão
   "tentar de novo" da faixa de aviso.

### Ordem: primeiro enviar, depois baixar

O **push** vem antes do **pull** de propósito. Se fosse o contrário, uma
nota escrita offline seria sobrescrita pela versão antiga que ainda está na
nuvem — e o texto que a pessoa acabou de digitar sumiria.

### Resolução de conflitos: *last write wins* por `updatedAt`

Na etapa de pull, cada documento remoto é comparado com a linha local:

| Situação | O que acontece |
|---|---|
| Não existe localmente | É inserido |
| Existe e está **pendente** | O local vence (já foi enviado no push) |
| Existe, `synced`, e o remoto é mais novo | O remoto substitui o local |
| Existe, `synced`, e o local é igual ou mais novo | Nada muda |

As datas são gravadas em **UTC**, para que a comparação funcione entre
aparelhos em fusos diferentes.

### Exclusões

Há duas exclusões diferentes, e elas sincronizam de formas diferentes:

- **Lixeira (temporária):** vira um `update` com `isDeleted: true`. O
  documento continua na nuvem, então a lixeira é a mesma em todos os
  aparelhos.
- **Definitiva:** apaga o documento remoto e **só então** a linha local. Se
  a remoção na nuvem falhar, a linha local é mantida como `pendingDelete`
  em vez de ser apagada — apagar só o local faria o documento voltar no
  próximo pull, e a nota "ressuscitaria".

Uma linha local já `synced` que **desapareceu** da nuvem foi excluída em
definitivo em outro aparelho, então também é removida aqui.

### Ordem entre categorias e notas

As categorias são enviadas antes das notas, porque uma nota pode apontar
para uma categoria que ainda não existe na nuvem.

---

## Tratamento de erros

Todas as falhas do Firestore são convertidas em `CloudException` por
`FirestoreService._guard`, com uma mensagem em português e um sinal
`isOffline` dizendo se vale a pena tentar de novo:

| Código do Firebase | Tratamento |
|---|---|
| `unavailable`, `deadline-exceeded`, `network-request-failed` | Tratado como falta de conexão. A operação **continua pendente** e a faixa avisa que será enviada depois. |
| `permission-denied` | As regras recusaram o acesso. Pede para entrar novamente. |
| `unauthenticated` | Sessão expirada. Pede novo login. |
| Qualquer outro | Mensagem genérica com o código, sem expor detalhes do SDK. |

Na interface:

- `SyncBanner` mostra o estado (sincronizando, sem conexão, erro) e quantas
  notas estão na fila, com botão "tentar de novo";
- o cartão da nota pendente exibe um ícone de nuvem cortada;
- salvar uma nota offline mostra um aviso, **mas a nota é salva** e a tela
  fecha normalmente — a falha de rede é um aviso, não um erro que impede o
  trabalho.

Os erros de autenticação recebem o mesmo tratamento em `AuthService`:
`user-not-found`, `wrong-password`, `email-already-in-use`, `weak-password`
e `network-request-failed` viram mensagens específicas em vez de um
"não foi possível entrar" genérico.

---

## Autenticação e segurança dos dados

### Autenticação

- Firebase Authentication com **e-mail e senha**.
- O aplicativo **não guarda senhas**: o SDK do Firebase cuida das
  credenciais e do token de sessão.
- `AuthGate` (em `main.dart`) ouve `authStateChanges`. Isso restaura a
  sessão sozinho quando o aplicativo é reaberto e leva de volta ao login
  assim que o usuário sai, de qualquer tela.

### Isolamento entre usuários

Em **três** camadas:

1. **No banco local:** toda consulta filtra por `uid = ?`.
2. **Na estrutura da nuvem:** as notas ficam em `users/{uid}/notes`. O
   Firestore não permite consultar uma subcoleção sem passar pelo caminho
   completo, então não existe consulta capaz de devolver as notas de outra
   pessoa.
3. **Nas regras de segurança** (`firestore.rules`), que são a única camada
   que o usuário não consegue contornar — as outras duas rodam no aparelho
   dele:

```javascript
function isOwner(userId) {
  return request.auth != null && request.auth.uid == userId;
}

match /users/{userId}/notes/{noteId} {
  allow read, delete: if isOwner(userId);
  allow create, update: if isOwner(userId) && uidMatches(userId);
}
```

`uidMatches` ainda confere se o campo `uid` **de dentro** do documento bate
com o dono do caminho, impedindo que alguém grave na própria subcoleção um
documento marcado como pertencente a outra pessoa. Qualquer caminho não
previsto cai no `match /{document=**}` final, que nega tudo.

### O que não está no repositório

Nenhuma senha, chave privada ou credencial de conta de serviço. Os arquivos
`firebase_options.dart` e `google-services.json` contêm apenas
identificadores **públicos** de cliente, que são extraíveis de qualquer APK
publicado — a proteção real vem da autenticação e das regras acima.

---

## Testes

`test/note_repository_test.dart` testa a integração de verdade: o SQLite
roda em memória com `sqflite_common_ffi` e o Firestore é substituído por
`fake_cloud_firestore`.

```bash
flutter test
```

Os 12 testes cobrem:

| Grupo | O que é verificado |
|---|---|
| CRUD e integração | Salvar grava nos dois bancos; editar reaproveita o UUID; **uma instalação nova recupera as notas da nuvem**; as notas de um usuário não aparecem para outro |
| Categorias e pesquisa | A nota guarda a categoria; excluir a categoria mantém as notas; a pesquisa acha por título, por conteúdo e ignora acentos; a ordenação por data funciona nos dois sentidos |
| Lixeira | A nota sai da lista, vai para a lixeira (com `isDeleted: true` na nuvem) e volta; a exclusão definitiva apaga local e nuvem |
| Falhas de conexão | Sem internet a nota é salva localmente e fica **pendente**; quando a conexão volta, a fila sobe sozinha |

---

## Capturas de tela

As imagens ficam em [`docs/screenshots/`](docs/screenshots/). Veja o
[guia de capturas](docs/screenshots/README.md) para a lista do que registrar.

### Aplicativo

| Tela | Imagem |
|---|---|
| Login | `docs/screenshots/01-login.png` |
| Lista de notas com categorias | `docs/screenshots/02-notas.png` |
| Pesquisa em funcionamento | `docs/screenshots/03-pesquisa.png` |
| Formulário com categoria | `docs/screenshots/04-formulario.png` |
| Gerenciador de categorias | `docs/screenshots/05-categorias.png` |
| Lixeira com recuperação | `docs/screenshots/06-lixeira.png` |
| Aviso de sincronização pendente | `docs/screenshots/07-offline.png` |

### Evidências no Firebase

| Evidência | Imagem |
|---|---|
| Coleção `users/{uid}/notes` no console | `docs/screenshots/08-firestore-notas.png` |
| Documento de uma nota aberto | `docs/screenshots/09-firestore-documento.png` |
| Coleção `users/{uid}/categories` | `docs/screenshots/10-firestore-categorias.png` |
| Usuários em Authentication | `docs/screenshots/11-authentication.png` |
| Regras publicadas em Firestore → Regras | `docs/screenshots/12-regras.png` |

---

## Fluxo de trabalho com Git

- Repositório original: `LopesBrendinha/bloco_de_nota_turma_B` (remote `upstream`).
- Fork: `FelipeIsmael-dev/bloco_de_nota_turma_B` (remote `origin`).
- Todo o desenvolvimento foi feito na branch **`desenvolvimento`**, nunca na
  `main`.
- Pull Request aberto do fork para a branch `main` do repositório original.
