# Bloco de Notas

Aplicativo Flutter de notas com **armazenamento local (SQLite) sincronizado
com o Cloud Firestore**, autenticação por e-mail e senha, categorias,
pesquisa e lixeira com recuperação.

O objetivo é escrever e organizar notas no aparelho, com acesso imediato e
funcionamento sem internet, mantendo tudo salvo na nuvem — de modo que ao
entrar novamente, ou em outra instalação, as notas voltem como estavam.

## Funcionalidades

- **Notas:** cadastrar, consultar, editar e excluir, gravando no SQLite e no
  Firestore. Cada nota pertence ao `uid` do usuário autenticado.
- **Categorias:** criar, renomear, escolher a cor e excluir. Uma categoria
  por nota, com filtro por chips. Excluir a categoria não exclui as notas.
- **Pesquisa:** por título e conteúdo, ignorando maiúsculas e acentos.
- **Lixeira com recuperação** (funcionalidade adicional): excluir manda a
  nota para a lixeira, de onde ela pode voltar ou ser apagada de vez.
- **Ordenação** por data de criação, de atualização ou por título.
- Aviso na tela quando há notas esperando conexão, com nova tentativa.

## Tecnologias

`firebase_core`, `firebase_auth`, `cloud_firestore`, `sqflite`, `path`,
`uuid` e `intl`. Nos testes, `sqflite_common_ffi` e `fake_cloud_firestore`.

## Como executar

```bash
flutter pub get
flutter run
```

```bash
flutter test
```

## Configurar o Firebase

Para usar outro projeto Firebase:

1. No [console](https://console.firebase.google.com), crie o projeto.
2. Em **Authentication**, habilite **E-mail/senha**.
3. Em **Firestore Database**, crie o banco (isso também ativa a API do
   Cloud Firestore, sem a qual nenhuma gravação chega ao servidor).
4. Gere os arquivos de configuração:

   ```bash
   dart pub global activate flutterfire_cli && flutterfire configure
   ```

5. Publique as regras versionadas em `firestore.rules`:

   ```bash
   firebase deploy --only firestore:rules
   ```

`firebase_options.dart` e `google-services.json` contêm apenas
identificadores públicos de cliente, extraíveis de qualquer APK. O
repositório não tem senhas nem chaves de conta de serviço — quem protege os
dados é a autenticação somada às regras do passo 5.

## Arquitetura

As telas falam só com o repositório, que decide o que vai para onde.

```text
screens/ + widgets/        interface
        ↓
repositories/              NoteRepository: coordena os dois bancos
        ↓                           ↓
database/                  services/
DatabaseHelper (SQLite)    FirestoreService, AuthService
```

```text
lib/
├── main.dart              Firebase, tema e AuthGate
├── models/                note, note_category, note_sort, sync_status
├── database/              database_helper.dart (esquema, migração, consultas)
├── services/              auth_service.dart, firestore_service.dart
├── repositories/          note_repository.dart, sync_outcome.dart
├── screens/               login, register, notes, note_form, categories, trash
├── widgets/               note_card.dart, sync_banner.dart
└── utils/                 app_date_format.dart, text_normalizer.dart
```

## Padrões de projeto

- **Singleton** (`DatabaseHelper`): uma conexão só com o `notes.db`. Várias
  conexões disputando o arquivo causariam `database is locked`.
- **Repository** (`NoteRepository`): a regra "grava local, tenta a nuvem, se
  falhar deixa pendente" vale para toda escrita. No repositório ela existe
  uma vez; nas telas seria repetida — e esquecida — em cada botão.
- **Data Mapper** (`toLocalMap`/`toRemoteMap` nos modelos): os dois bancos
  guardam a mesma nota de formas diferentes (`is_deleted` 0/1 e `snake_case`
  no SQLite, `isDeleted` booleano e `camelCase` no Firestore). Assim nenhum
  dos dois precisa conhecer o formato do outro.
- **Injeção por construtor**: é o que permite os testes trocarem o Firestore
  por um falso.

## Armazenamento local

Tabelas `notes` e `categories` no `notes.db`. Além dos dados, cada linha
guarda `id` (UUID), `created_at`/`updated_at` em UTC, `is_deleted` e
`sync_status` (`0` sincronizado, `1` a enviar, `2` a excluir).

A coluna `search_text` guarda título e conteúdo em minúsculas e sem acentos.
Ela existe porque o `LIKE COLLATE NOCASE` do SQLite só ignora maiúsculas
ASCII — sem ela, `ANIVERSÁRIO` não encontrava `Aniversário`.

Quem já usava a versão anterior não perde nada: o `onUpgrade` copia as notas
antigas gerando um UUID para cada uma e marcando-as como pendentes.

## Integração com o Firebase

```text
users/{uid}/notes/{noteId}
users/{uid}/categories/{categoryId}
```

Os dados de cada pessoa ficam dentro do documento dela — é o que torna as
regras de segurança simples de escrever e difíceis de errar.

**O que faz a sincronização funcionar:** o `id` da nota é um UUID gerado no
aplicativo e usado ao mesmo tempo como chave no SQLite e como ID do
documento no Firestore. Sem ele o `AUTOINCREMENT` daria IDs diferentes em
cada aparelho e não haveria como saber que uma linha local e um documento da
nuvem são a mesma nota.

## Sincronização e tratamento de erros

Toda escrita vai primeiro para o SQLite marcada como pendente, depois tenta
a nuvem. Como o banco local não depende de rede, a ação do usuário nunca
falha.

`synchronize()` envia a fila **antes** de baixar. Na ordem inversa, uma nota
escrita offline seria sobrescrita pela versão antiga que ainda está na nuvem.

Conflitos seguem *last write wins* por `updatedAt` (em UTC, para funcionar
entre fusos), com o local vencendo enquanto estiver pendente.

As duas exclusões sincronizam de formas diferentes:

- **lixeira:** vira um `update` com `isDeleted: true`, então ela é a mesma em
  todos os aparelhos;
- **definitiva:** apaga o documento remoto e só então a linha local. Apagar
  só o local faria a nota voltar no próximo download.

Erros viram `CloudException` com mensagem em português. Falta de conexão
mantém a operação pendente; `permission-denied` e sessão expirada pedem novo
login.

Há um **timeout** nas chamadas remotas porque o SDK do Firestore não lança
erro quando não alcança o servidor: ele enfileira e retenta para sempre, e o
`Future` nunca completa. Sem o timeout a tela trava em silêncio.

## Autenticação e segurança

Firebase Authentication com e-mail e senha; o aplicativo não guarda senhas.
O `AuthGate` ouve `authStateChanges`, o que restaura a sessão ao reabrir o
app e volta ao login quando o usuário sai.

O isolamento entre usuários tem três camadas: o filtro `uid = ?` nas
consultas locais, a estrutura `users/{uid}` na nuvem e as regras de
segurança — a única que o usuário não consegue contornar, já que as outras
duas rodam no aparelho dele:

```javascript
match /users/{userId}/notes/{noteId} {
  allow read, delete: if isOwner(userId);
  allow create, update: if isOwner(userId) && uidMatches(userId);
}
```

`uidMatches` ainda confere se o campo `uid` de dentro do documento bate com
o dono do caminho. Qualquer outro caminho é negado.

## Testes

`flutter test` — 13 testes com o SQLite em memória e o Firestore
substituído por um falso. Cobrem o CRUD nos dois bancos, a recuperação das
notas em uma instalação nova, o isolamento entre usuários, categorias,
pesquisa com acentos, a lixeira e a fila que sobe sozinha quando a conexão
volta.

## Capturas de tela

Em [`docs/screenshots/`](docs/screenshots/), com a lista do que cada imagem
registra no [guia](docs/screenshots/README.md).

## Git

Fork de `LopesBrendinha/bloco_de_nota_turma_B`, desenvolvimento na branch
`desenvolvimento` e Pull Request para a `main` do repositório original.
