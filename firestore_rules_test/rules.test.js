// Testa firestore.rules no emulador local: `npm test` nesta pasta.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, collection, getDocs, Timestamp } from 'firebase/firestore';

let env;

const note = (uid, extra = {}) => ({
  uid,
  title: 'Título',
  content: 'Conteúdo',
  category: 'Estudos',
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
  trashed: false,
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bloco-notas',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/bob/notes/n1'), note('bob')),
  );
});

after(() => env.cleanup());

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

test('dono pode criar, ler, editar e excluir as próprias notas', async () => {
  const alice = db('alice');
  const ref = doc(alice, 'users/alice/notes/a1');
  await assertSucceeds(setDoc(ref, note('alice')));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(setDoc(ref, note('alice', { title: 'Editado' })));
  await assertSucceeds(getDocs(collection(alice, 'users/alice/notes')));
  await assertSucceeds(deleteDoc(ref));
});

test('usuário não lê nem lista notas de outro', async () => {
  const alice = db('alice');
  await assertFails(getDoc(doc(alice, 'users/bob/notes/n1')));
  await assertFails(getDocs(collection(alice, 'users/bob/notes')));
});

test('usuário não altera nem exclui notas de outro', async () => {
  const alice = db('alice');
  await assertFails(setDoc(doc(alice, 'users/bob/notes/n1'), note('bob', { title: 'hack' })));
  await assertFails(deleteDoc(doc(alice, 'users/bob/notes/n1')));
});

test('não pode gravar nota com uid de outra pessoa na própria pasta', async () => {
  await assertFails(setDoc(doc(db('alice'), 'users/alice/notes/x'), note('bob')));
});

test('visitante não autenticado não acessa nada', async () => {
  await assertFails(getDoc(doc(db(null), 'users/bob/notes/n1')));
  await assertFails(setDoc(doc(db(null), 'users/bob/notes/n2'), note('bob')));
});

test('rejeita formato inválido e campos extras', async () => {
  const ref = doc(db('alice'), 'users/alice/notes/x');
  await assertFails(setDoc(ref, note('alice', { title: 123 })));
  await assertFails(setDoc(ref, note('alice', { category: '' })));
  await assertFails(setDoc(ref, note('alice', { admin: true })));
});

test('caminhos fora de users/{uid}/notes são bloqueados', async () => {
  await assertFails(setDoc(doc(db('alice'), 'outros/x'), { a: 1 }));
});
