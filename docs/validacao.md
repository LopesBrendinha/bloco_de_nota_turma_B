# Testes do aplicativo

Fiz os testes em 02/11/2026, com Flutter 3.47.6 e Dart 3.13.5 no Windows, usando Chrome e SQLite persistente no navegador.

## Resultado dos testes

| Verificação | Resultado |
| --- | --- |
| Testes Dart do SQLite e sincronização | 10 testes aprovados |
| Regras de segurança no Firestore Emulator | 4 grupos de testes aprovados |
| Aplicativo completo no Chrome com Firebase Emulator | Aprovado |
| Aplicativo completo no Chrome com Firebase real | Aprovado |
| `flutter analyze` | Sem problemas encontrados |
| `flutter build web` com configuração do Firebase real | Gerado com sucesso |
| `flutter build apk --debug` com configuração Android do Firebase real | APK gerado com sucesso |

Usei o projeto **bloco-de-notas-544ec**, banco `(default)`, região `southamerica-east1`, no plano Spark. Publiquei as regras deste repositório pelo Firebase CLI.

No teste de integração com a nuvem, conferi a criação de uma conta, a gravação de uma nota no SQLite, o envio ao Firestore e a consulta do documento com `Source.server`. Depois, testei a pesquisa por conteúdo sem acento, o arquivamento e o desarquivamento. Para conferir a recuperação das notas, usei um segundo arquivo SQLite vazio.

Simulei uma falha de conexão pela interface `NotesCloud`, retornando `unavailable`. A edição continuou salva e pendente no SQLite. Ao liberar a comunicação, o app enviou a alteração ao Firestore e confirmou o texto atualizado no servidor. Nesse teste, a falha acontece no serviço; a rede do computador continua ligada.

Também testei a saída e a entrada na conta, a criação e a exclusão de uma nota temporária e a remoção do texto no marcador de exclusão do Firestore. Para conferir as regras de segurança, usei outra conta em uma segunda instância do Firebase. As tentativas de consultar e alterar a nota da primeira conta retornaram `permission-denied`. A leitura sem autenticação também foi negada.

## Nota usada no teste

```text
users/sLd4dFL96QMTEXeHo3HaIMf9dHl2/notes/33785f52-f788-4ce7-b9fc-a58323adf0b6
```

Esse caminho permite localizar a nota no console do Firebase. Ela ficou com o título “Revisão concluída”, na categoria Faculdade. As capturas de criação, pesquisa e arquivamento mostram o estado da nota antes da última edição.

- [Documento no Firestore](screenshots/firebase-documento.png)
- [Regras publicadas](screenshots/firebase-regras.png)
- [Listagem com nota sincronizada](screenshots/nuvem-notas.png)
- [Editor e categoria criada](screenshots/nuvem-editor.png)
- [Pesquisa pelo conteúdo](screenshots/nuvem-pesquisa.png)
- [Nota arquivada](screenshots/nuvem-arquivo.png)
- [Alteração pendente após falha simulada](screenshots/nuvem-pendente.png)
- [Estado final, após nova entrada e sincronização](screenshots/nuvem-final.png)

As imagens `firebase-*.png` mostram o console do Firebase, e as imagens `nuvem-*.png` mostram o app conectado à nuvem. As imagens `emulador-*.png` são da execução local com os emuladores.

## Roteiro de teste manual

1. Configure seu Firebase como descrito no README e publique as regras.
2. Entre em uma conta, crie uma nota com uma categoria nova e espere a indicação “Sincronizada”.
3. Confira o documento em `users/{uid}/notes` no console do Firestore.
4. Pesquise uma palavra do título e outra que apareça apenas no conteúdo. Teste também acentos e maiúsculas.
5. Edite a nota, confira a alteração no console, arquive e desarquive.
6. Interrompa a conexão do dispositivo, altere uma nota e confira que ela continua acessível e pendente. Restabeleça a conexão e sincronize.
7. Saia e entre novamente. Abra o app em outro navegador ou instalação, com armazenamento local vazio, usando a mesma conta; as notas devem ser recuperadas.
8. Entre em outra conta: as notas anteriores não devem aparecer. As tentativas diretas de acesso ao caminho de outra conta devem ser negadas pelas regras.
9. Exclua uma nota de teste e sincronize. O conteúdo deve desaparecer das consultas, com um marcador `deleted = true` e texto vazio no Firestore.

Os testes de execução foram feitos no Chrome. Gerei o APK Android, mas ainda não fiz testes em aparelho físico. A recuperação foi conferida com um segundo arquivo SQLite vazio, usando a mesma conta. O teste de novo login sai e entra novamente no app. Em aparelhos com relógios diferentes, vale considerar a regra de conflito por `updatedAt` descrita no README.
