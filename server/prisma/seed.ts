import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Создаём админа
  const adminEmail = process.env.ADMIN_EMAIL || 'admin@amoria.app';
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
  const passwordHash = await bcrypt.hash(adminPassword, 12);

  await prisma.user.upsert({
    where: { email: adminEmail },
    update: { role: 'admin' },
    create: {
      email: adminEmail,
      passwordHash,
      displayName: 'Admin',
      role: 'admin',
      profile: { create: { displayName: 'Admin' } },
      currency: { create: {} },
    },
  });
  console.log(`Admin user: ${adminEmail}`);

  await prisma.novel.upsert({
    where: { id: 'demo_novel' },
    update: {},
    create: {
      id: 'demo_novel',
      title: 'Тени Петербурга',
      description: 'Мистическая история в ночном Петербурге. Встреча с загадочным незнакомцем изменит всё...',
      author: 'Amoria Team',
      tags: ['мистика', 'романтика', 'Петербург'],
      version: 1,
      chaptersCount: 1,
      isPublished: true,
    },
  });

  await prisma.novel.upsert({
    where: { id: 'demo_novel_2' },
    update: {},
    create: {
      id: 'demo_novel_2',
      title: 'Парижские тайны',
      description: 'Стажировка в модном доме Парижа. Интриги, страсть и выбор между карьерой и любовью...',
      author: 'Amoria Team',
      tags: ['романтика', 'драма', 'Париж'],
      version: 1,
      chaptersCount: 2,
      isPublished: true,
    },
  });

  // Конфигурация игры
  await prisma.gameConfig.upsert({
    where: { id: 'singleton' },
    update: {},
    create: {
      id: 'singleton',
      version: 1,
      economy: {
        maxTickets: 5,
        ticketRefillMinutes: 30,
        startDiamonds: 50,
        startTickets: 5,
        diamondCostPerTicket: 10,
      },
      ads: {
        maxAdsPerDay: 5,
        diamondReward: 3,
        ticketReward: 1,
      },
      iap: {
        diamonds_20:  { diamonds: 20 },
        diamonds_60:  { diamonds: 60 },
        diamonds_150: { diamonds: 150 },
        diamonds_500: { diamonds: 500 },
        tickets_5:    { tickets: 5 },
        starter_bundle: { diamonds: 100, tickets: 10 },
      },
      vip: {
        dailyDiamonds: 5,
        unlimitedTickets: true,
        earlyAccess: true,
        noAds: true,
        exclusiveFrame: true,
      },
      daily: [
        { day: 1, diamonds: 5,  tickets: 0, label: '5 💎' },
        { day: 2, diamonds: 0,  tickets: 1, label: '1 ⚡' },
        { day: 3, diamonds: 10, tickets: 0, label: '10 💎' },
        { day: 4, diamonds: 0,  tickets: 2, label: '2 ⚡' },
        { day: 5, diamonds: 15, tickets: 0, label: '15 💎' },
        { day: 6, diamonds: 0,  tickets: 3, label: '3 ⚡' },
        { day: 7, diamonds: 30, tickets: 0, label: '30 💎' },
      ],
      achievements: [
        { id: 'first_story',    title: 'Первая история',  icon: 'auto_stories', diamondReward: 10, description: 'Начни первую новеллу' },
        { id: 'first_choice',   title: 'Первый выбор',    icon: 'touch_app',    diamondReward: 5,  description: 'Сделай первый выбор' },
        { id: 'five_chapters',  title: '5 глав',          icon: 'menu_book',    diamondReward: 15, description: 'Прочитай 5 глав' },
        { id: 'first_love',     title: 'Первая любовь',   icon: 'favorite',     diamondReward: 10, description: '10+ очков отношений' },
        { id: 'completionist',  title: 'Прохождение',     icon: 'emoji_events', diamondReward: 25, description: 'Пройди новеллу до конца' },
        { id: 'collector',      title: 'Коллекционер',    icon: 'collections',  diamondReward: 15, description: 'Разблокируй 3 CG-арта' },
        { id: 'brave_heart',    title: 'Храброе сердце',  icon: 'shield',       diamondReward: 5,  description: 'Выбери смелый вариант' },
        { id: 'mystery_solver', title: 'Детектив',        icon: 'search',       diamondReward: 20, description: 'Найди 5 улик' },
        { id: 'ten_choices',    title: '10 выборов',      icon: 'touch_app',    diamondReward: 10, description: 'Сделай 10 выборов' },
        { id: 'diamond_spender',title: 'Транжира',        icon: 'diamond',      diamondReward: 20, description: 'Потрать 100 алмазов' },
      ],
      localization: {
        ru: {
          app_title: 'Amoria',
          tab_home: 'Главная',
          tab_catalog: 'Каталог',
          tab_profile: 'Профиль',
          btn_play: 'Начать историю',
          btn_continue: 'Продолжить',
          btn_shop: 'Магазин',
          no_tickets_title: 'Нет билетов',
          no_tickets_body: 'Подожди или посмотри рекламу',
          vip_title: 'VIP-подписка',
          daily_title: 'Ежедневная награда',
          daily_claim: 'Забрать награду!',
          version: 'Версия 1.0.0',
        },
        en: {
          app_title: 'Amoria',
          tab_home: 'Home',
          tab_catalog: 'Catalog',
          tab_profile: 'Profile',
          btn_play: 'Start Story',
          btn_continue: 'Continue',
          btn_shop: 'Shop',
          no_tickets_title: 'No Tickets',
          no_tickets_body: 'Wait or watch an ad',
          vip_title: 'VIP Subscription',
          daily_title: 'Daily Reward',
          daily_claim: 'Claim Reward!',
          version: 'Version 1.0.0',
        },
      },
    },
  });
  console.log('Game config seeded.');

  console.log('Seed complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
