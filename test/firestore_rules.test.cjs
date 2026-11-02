const { test, before, after, beforeEach } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;
const data = () => ({ uid: 'ana', title: 'Aula', content: 'Anotações', category: 'Estudos',
  createdAt: 1000, updatedAt: 1000, archived: false, deleted: false,
  changeId: '00000000-0000-4000-8000-000000000001' });
const reference = (db, uid = 'ana') => doc(db, `users/${uid}/notes/nota-1`);
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-bloco-notas',
    firestore: { host: '127.0.0.1', port: 8080, rules: readFileSync('firestore.rules', 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => setDoc(reference(context.firestore()), data()));
});
after(async () => { await env?.cleanup(); });

test('dono pode consultar, criar, editar, arquivar e excluir logicamente', async () => {
  const db = env.authenticatedContext('ana').firestore();
  await assertSucceeds(getDoc(reference(db)));
  await assertSucceeds(getDocs(collection(db, 'users/ana/notes')));
  await assertSucceeds(setDoc(doc(db, 'users/ana/notes/nova'), data()));
  await assertSucceeds(updateDoc(reference(db), { title: 'Revisada', updatedAt: 2000 }));
  await assertSucceeds(updateDoc(reference(db), { archived: true, updatedAt: 3000 }));
  await assertSucceeds(updateDoc(reference(db), { deleted: true, title: '', content: '', updatedAt: 4000 }));
});
test('outra conta não pode ler, listar, criar, editar ou excluir notas da dona', async () => {
  const db = env.authenticatedContext('bia').firestore();
  await assertFails(getDoc(reference(db)));
  await assertFails(getDocs(collection(db, 'users/ana/notes')));
  await assertFails(setDoc(doc(db, 'users/ana/notes/nova'), data()));
  await assertFails(updateDoc(reference(db), { content: 'Invadida' }));
  await assertFails(deleteDoc(reference(db)));
});
test('visitante não autenticado não acessa notas', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(reference(db)));
  await assertFails(setDoc(reference(db), data()));
});
test('valida dono, campos, limites e preserva criação e ordem das versões', async () => {
  const db = env.authenticatedContext('ana').firestore();
  for (const change of [{ uid: 'bia' }, { title: 'a'.repeat(121) }, { content: 'a'.repeat(20001) },
    { category: '' }, { category: 'a'.repeat(41) }, { archived: 'sim' }, { createdAt: 2 },
    { updatedAt: 999 }, { changeId: '' }, { extra: true }]) {
    await assertFails(updateDoc(reference(db), change));
  }
  await assertFails(deleteDoc(reference(db)));
  await assertFails(getDoc(doc(db, 'outraColecao/nota')));
});
