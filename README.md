# Bloco de Notas — Turma B

Aplicativo Flutter baseado no projeto da professora para organizar notas e tarefas.

## Funcionalidades

- Cadastro e login por e-mail e senha com Firebase Authentication.
- Criação, consulta, edição e exclusão de notas do usuário conectado.
- Armazenamento local e recuperação das notas salvas na nuvem.
- Categorias prontas e criação de categorias no formulário. As categorias usadas nas notas podem ser reutilizadas em outras notas.
- Pesquisa por título, conteúdo e texto dos itens da checklist, sem diferenciar maiúsculas e minúsculas.
- Checklist com itens editáveis, marcação de conclusão e exclusão de tarefas.
- Mensagens de sincronização e preservação de alterações locais quando a nuvem não pode ser acessada.

Na checklist, o último campo fica vazio. Ao começar a digitar, ele se torna uma tarefa com caixa de seleção e botão de excluir, e um novo campo vazio aparece abaixo. É possível salvar uma nota só com tarefas. O campo vazio não é salvo. Use o botão de salvar no topo para confirmar as alterações da nota e da checklist.

## Tecnologias

| Dependência | Uso |
| --- | --- |
| Flutter e Dart | Interface e lógica do aplicativo |
| `firebase_core` | Inicialização do Firebase |
| `firebase_auth` | Autenticação |
| `cloud_firestore` | Dados na nuvem |
| `sqflite` e `path` | SQLite no Android e caminho do banco |
| `sqflite_common_ffi_web` | SQLite no navegador, persistido no IndexedDB | Especialmente para facilitar os testes no computador

As versões estão em `pubspec.yaml` e `pubspec.lock`. O projeto exige Dart compatível com `^3.12.2` e um Flutter que inclua essa versão ou uma versão compatível.

## Executar

Com Flutter instalado e disponível no terminal, na pasta do projeto:

```powershell
flutter pub get
flutter run -d edge --web-port=8080
```

Também é possível usar Chrome, substituindo `edge` por `chrome`. Mantenha a mesma porta para acessar o mesmo banco local do navegador.

Os arquivos `web/sqflite_sw.js` e `web/sqlite3.wasm` acompanham o repositório. São componentes gerados do SQLite para web, não arquivos com notas dos usuários. Caso seja necessário regenerá-los:

```powershell
dart run sqflite_common_ffi_web:setup
```

## Configurar o Firebase

A configuração de cliente incluída aponta para `bloco-7bf55`. Para avaliar o aplicativo nesse projeto, crie uma conta pela tela de cadastro. Cada conta acessa somente suas próprias notas.

Para utilizar outro projeto Firebase:

1. Crie o projeto no [Console do Firebase](https://console.firebase.google.com/).
2. Em Authentication, habilite o método E-mail/senha.
3. Crie um Cloud Firestore Standard, com banco `(default)`, e selecione o modo de produção.
4. Com Node.js instalado, configure as ferramentas e vincule o aplicativo. Substitua `SEU_ID` pelo ID do seu projeto:

```powershell
npm.cmd install -g firebase-tools
firebase.cmd login
dart pub global activate flutterfire_cli
dart pub global run flutterfire_cli:flutterfire configure --project=SEU_ID --platforms=android,web
firebase.cmd deploy --only firestore:rules --project=SEU_ID
```

## Organização e padrões utilizados

```text
lib/
  main.dart
  firebase_options.dart
  models/
    note.dart
    checklist_item.dart
  database/
    database_helper.dart
  services/
    auth_service.dart
    note_sync_service.dart
  screens/
    login_page.dart
    register_page.dart
    notes_page.dart
    note_form_page.dart
  widgets/
    note_card.dart
firestore.rules
docs/imagens/
```

## Armazenamento e sincronização

O banco local se chama `notes.db`: no Android fica no armazenamento interno do aplicativo; na web, seus dados são persistidos no IndexedDB do navegador. A tabela `notes` guarda título, conteúdo, data, categoria, checklist e informações de sincronização. A checklist é salva como JSON no SQLite e como uma lista de objetos no Firestore.

A versão 4 do banco acrescenta a checklist. As migrações mantêm os dados anteriores, preenchendo categorias ausentes com `Sem categoria` e checklists ausentes com uma lista vazia.

Cada nota mantém um `id` local e recebe um `remoteId` para identificar o documento na nuvem. O `uid` associa os dois armazenamentos à conta autenticada. Os documentos ficam em:

```text
users/{uid}/notes/{remoteId}
```

O fluxo é:

1. Salvar, editar ou excluir uma nota registra a mudança primeiro no SQLite, como pendente.
2. A sincronização acontece ao carregar a lista, depois de salvar ou excluir e ao pressionar o botão de sincronizar.
3. O serviço consulta o servidor e mescla os documentos com o SQLite. Alterações locais pendentes são preservadas; exclusões já confirmadas na nuvem prevalecem.
4. As pendências são enviadas para o documento correspondente no Firestore. O campo `updatedAt` usa o horário do servidor.
5. A confirmação só limpa a pendência da revisão enviada. Uma edição local mais recente continua pendente.

Ao excluir, a nota some da lista imediatamente. Após a confirmação da nuvem, ela é removida fisicamente do SQLite. No Firestore permanece uma marcação `deleted: true`, com título, conteúdo e checklist vazios. Isso impede que uma cópia antiga faça a nota reaparecer.

Requisições à nuvem têm limite de espera de 10 segundos. Falhas de conexão ou permissão são informadas na tela e mantêm as mudanças locais para outra tentativa. Cadastro e login precisam de conexão; depois de entrar, as notas disponíveis localmente podem ser editadas e pesquisadas sem conexão. Limpar os dados do navegador remove o armazenamento local, inclusive alterações ainda não enviadas.

## Autenticação e segurança

As consultas e alterações locais consideram o `uid`. As regras de `firestore.rules` permitem acesso apenas quando o usuário autenticado corresponde ao `uid` do caminho. Também verificam campos e tipos básicos e bloqueiam a restauração de notas já marcadas como excluídas.