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

  console.log('Seed complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
