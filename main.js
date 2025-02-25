const prompts = require("prompts");
require("colors");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const { spawn } = require("child_process");
const displayHeader = require("./src/banner.js");

displayHeader();

 console.log("List Modul AUTO\n");
console.log(`⏩ bebop`.red);
console.log(`⏩ Uniswap`.red);
console.log(`⏩ bean`.red);
console.log(`⏩ Rubic Swap`.red);
console.log(`⏩ Magma Staking`.red);
console.log(`⏩ Izumi Swap`.red);
console.log(`⏩ Kitsu Staking`.red);
console.log(`⏩ aPriori Staking`.red);
console.log(`⏩ Auto Send`.red);
console.log("");

// Replace with your Telegram Bot Token and Chat ID
const TELEGRAM_BOT_TOKEN = '5264213507:AAESDDORGTgny2qPNhZ5O89H8jVZ9BtoF2c';
const TELEGRAM_CHAT_ID = '903018274';

// Function to send Telegram messages
async function sendTelegramMessage(message) {
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  const payload = {
    chat_id: TELEGRAM_CHAT_ID,
    text: message
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (!data.ok) {
      console.error(`❌ Telegram Error: ${data.description}`);
    } else {
      console.log("📬 Telegram notification sent.");
    }
  } catch (error) {
    console.error(`❌ Failed to send Telegram message: ${error.message}`);
  }
}

 const scripts = [
    { name: "Deploy Kontrak", path: "./modul/deploy.mjs" },
    { name: "Uniswap", path: "./modul/uniswap.js" },
    { name: "Rubic Swap", path: "./modul/rubic.js" },
    { name: "Bean Swap", path: "./modul/bean.js" },
    { name: "Magma Staking", path: "./modul/magma.js" },
    { name: "Izumi Swap", path: "./modul/izumi.js" },
    { name: "aPriori Staking", path: "./modul/apriori.js" },
    { name: "Bebob Swap", path: "./modul/bebop.js" },
    { name: "Monorail", path: "./modul/mono.js" },
    { name: "Kitsu", path: "./modul/kitsu.js" },
    { name: "AutoSend", path: "./modul/AutoSend.js" },
  ];

async function runScript(script) {
  console.log(`\n✅ Running ${script.name}...`);
  await sendTelegramMessage(`🚀 Starting ${script.name}...`);

  return new Promise((resolve, reject) => {
    const process = spawn("node", [script.path]);

    // Capture stdout and send to Telegram
    process.stdout.on("data", async (data) => {
      const output = data.toString();
      console.log(output);

      // Send each TXN or important line to Telegram
      if (output.includes("Swap") || output.includes("TXN")) {
        await sendTelegramMessage(`🔄 ${script.name} Output:\n${output}`);
      }
    });

    // Capture stderr for errors
    process.stderr.on("data", async (data) => {
      const error = data.toString();
      console.error(error);
      await sendTelegramMessage(`❌ Error in ${script.name}:\n${error}`);
    });

    // On script completion
    process.on("close", async (code) => {
      if (code === 0) {
        console.log(`✅ Finished ${script.name}`);
        await sendTelegramMessage(`✅ Finished ${script.name}`);
        resolve();
      } else {
        console.error(`❌ Error in ${script.name} (Exit code: ${code})`);
        await sendTelegramMessage(`❌ Error in ${script.name} (Exit code: ${code})`);
        reject(new Error(`Script ${script.name} failed`));
      }
    });
  });
}

async function runScriptsSequentially(loopCount) {
  for (let i = 0; i < loopCount; i++) {
    for (const script of scripts) {
      await runScript(script);
    }
  }
  await sendTelegramMessage(`🎉 All scripts executed ${loopCount} time(s)!`);
}

async function main() {
  while (true) {
    const response = await prompts({
      type: "number",
      name: "loopCount",
      message: "Looping : ",
      validate: (value) => (value > 0 ? true : "Enter a valid number greater than 0"),
    });

    const loopCount = response.loopCount || 1;
    console.log(`\n🚀 Executing all scripts ${loopCount} times...\n`);
    await sendTelegramMessage(`🚀 Starting execution of all scripts (${loopCount} times)...`);

    await runScriptsSequentially(loopCount);

    console.log("\n✅✅ All scripts have been executed\n");
    await sendTelegramMessage("✅✅ All scripts have been executed successfully!");
  }
}

main();
