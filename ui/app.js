const root = document.getElementById('root');
const playerInfo = document.getElementById('playerInfo');
const playerName = document.getElementById('playerName');
const playerSteam = document.getElementById('playerSteam');
const profileFirst = document.getElementById('profileFirst');
const profileLast = document.getElementById('profileLast');
const profileJob = document.getElementById('profileJob');
const profileCash = document.getElementById('profileCash');
const profileBank = document.getElementById('profileBank');

function nui(name, payload = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
}

const DISCORD_URL = 'https://discord.gg/GhqNGkwtmT'; 
const RULES_URL = 'https://docs.google.com/document/d/1dKtvotruNvO0eaO1Z8VXtsNdYP77Qo6AUOxhPNohxKs/edit?usp=sharing';

document.getElementById('btnDiscord').addEventListener('click', () => {
  window.invokeNative('openUrl', DISCORD_URL);
  nui('close');
});
document.getElementById('btnClose').addEventListener('click', () => nui('close'));
document.getElementById('tileMap').addEventListener('click', () => nui('openMap'));
document.getElementById('tileDiscord').addEventListener('click', () => {
  window.invokeNative('openUrl', DISCORD_URL);
  nui('close');
});
document.getElementById('tileSettings').addEventListener('click', () => nui('openSettings'));
document.getElementById('tileSupport').addEventListener('click', () => nui('support'));

document.getElementById('tileRules').addEventListener('click', () => {

  window.invokeNative('openUrl', RULES_URL);
  nui('close');


});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') nui('close');
});

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || !data.action) return;

  if (data.action === 'open') {
    root.classList.remove('hidden');
    if (data.playerId && playerInfo) playerInfo.textContent = `ID: ${data.playerId}`;
    if (data.steamName && playerSteam) playerSteam.textContent = data.steamName;
    if (data.characterName && playerName) playerName.textContent = data.characterName;
    if (profileFirst && data.firstName) profileFirst.textContent = data.firstName;
    if (profileLast && data.lastName) profileLast.textContent = data.lastName;
    if (profileJob && data.job) profileJob.textContent = data.job;
    if (profileCash && data.cash) profileCash.textContent = data.cash;
    if (profileBank && data.bank) profileBank.textContent = data.bank;
  }


  if (data.action === 'close') {
    root.classList.add('hidden');
  }
});
