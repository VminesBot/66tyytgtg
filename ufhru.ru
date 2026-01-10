import os
import json
import random
import asyncio
import datetime
import time
from typing import Dict, List, Tuple, Optional
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes, MessageHandler, filters
from telegram.constants import ParseMode
import re

# В начале файла, после импортов:
BOT_SETTINGS = {
    'bot_username': '@ваш_бот',
    'admin_id': 123456789,  # ID администратора
    'min_bet': 10,
    'max_bet': 1000000,
    'games_enabled': True
}
# Конфигурация
BOT_TOKEN = "7567307567:AAHNkw_4gmm90K74W7InOF_GL75bDqfsRk4"
ADMIN_PASSWORD = "1221"
ADMIN_IDS = []
BONUS_AMOUNT = (50, 5000)
INITIAL_BALANCE = 5000
INITIAL_BITCOIN = 0
DUEL_TIMEOUT = 300  # 5 минут на принятие дуэли
# Коэффициенты для игр
MINE_MULTIPLIERS = {
    1: [1.05, 1.10, 1.15, 1.21, 1.28, 1.35, 1.43, 1.52, 1.62, 1.73, 1.87, 2.02, 2.20, 2.42, 2.69, 3.03, 3.46, 4.04, 4.85, 6.06],
    2: [1.05, 1.15, 1.26, 1.39, 1.53, 1.69, 1.87, 2.08, 2.32, 2.60, 2.94, 3.35, 3.85, 4.46, 5.23, 6.20, 7.44, 9.04, 11.16, 14.02],
    3: [1.10, 1.26, 1.45, 1.68, 1.96, 2.30, 2.72, 3.24, 3.90, 4.74, 5.82, 7.22, 9.06, 11.49, 14.75, 19.21, 25.32, 33.84, 45.96, 63.43],
    4: [1.15, 1.39, 1.68, 2.05, 2.53, 3.15, 3.97, 5.06, 6.54, 8.55, 11.33, 15.25, 20.83, 28.91, 40.81, 58.67, 86.05, 128.99, 197.85, 310.93],
    5: [1.21, 1.53, 1.96, 2.53, 3.32, 4.43, 6.01, 8.30, 11.66, 16.67, 24.31, 36.13, 54.81, 84.96, 134.78, 219.51, 366.58, 629.85, 1112.43, 2021.69],
    6: [1.28, 1.70, 2.30, 3.17, 4.43, 6.30, 9.13, 13.50, 20.39, 31.48, 49.76, 80.63, 133.86, 228.56, 401.68, 726.04, 1351.03, 2587.48, 5115.08, 10386.45]
}
PYRAMID_MULTIPLIERS = {
    1: [1.0, 1.46, 2.18, 3.27, 4.91, 7.37, 11.05, 16.57, 24.86, 37.29, 55.94, 83.91, 125.87, 188.8, 283.2, 424.8, 637.2],
    2: [1.0, 2.18, 4.91, 11.05, 24.86, 55.94, 125.87, 283.2, 637.2, 1433.7, 3225.8, 7258.0, 16330.5, 36743.6, 82673.1, 186000.0, 418500.0]
}
# Обновленные коэффициенты для башни
TOWER_MULTIPLIERS = {
    1: [1.21, 1.52, 1.89, 2.37, 2.96, 3.70, 4.63, 5.78, 7.23],
    2: [1.62, 2.69, 4.49, 7.48, 12.47, 20.79, 34.65, 57.75, 96.25],
    3: [2.42, 6.06, 15.16, 37.89, 94.73, 236.82, 592.04, 900.0, 1233.0],
    4: [4.85, 24.25, 121.25, 606.25, 3031.25, 3565.0, 4212.0, 5125.0, 6000.0]
}
GOLD_MULTIPLIERS = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
BITCOIN_RATE = 500
BITCOIN_RATE_PERCENTAGE = 0

HELPER_RANKS = {
    1: {
        "name": "Хелпер 1",
        "color": "🟢",
        "permissions": ["Просмотр заявок на бан"]
    },
    2: {
        "name": "Хелпер 2", 
        "color": "🟡",
        "permissions": ["Одобрение/отклонение банов", "Разбан пользователей"]
    },
    3: {
        "name": "Хелпер 3",
        "color": "🔴",
        "permissions": ["Одобрение кредитов", "Создание промокодов", "Просмотр статистики"]
    }
}

# Депозиты
DEPOSIT_RATES = {
    "3_days": {"term": 3, "interest": 2},
    "16_days": {"term": 16, "interest": 15},
    "30_days": {"term": 30, "interest": 25}
}
CREDIT_INTEREST = 10

# Бизнесы
BUSINESSES = {
    "larek": {"name": "Ларёк", "price": 2000000, "hourly_profit": 10500, "daily_profit": 255000, "emoji": "🏪"},
    "shinomontazh": {"name": "Шиномонтаж", "price": 4000000, "hourly_profit": 16800, "daily_profit": 405000, "emoji": "🔧"},
    "magazine24": {"name": "Магазин 24/7", "price": 8000000, "hourly_profit": 25000, "daily_profit": 600000, "emoji": "🏬"},
    "zapravka": {"name": "Заправка", "price": 15000000, "hourly_profit": 40000, "daily_profit": 960000, "emoji": "⛽"},
    "avtosalon": {"name": "Автосалон", "price": 22500000, "hourly_profit": 60000, "daily_profit": 1440000, "emoji": "🚗"}
}
# Цена чековой книжки
CHECKBOOK_PRICE = 100000  # 100,000 VsCoin за чековую книжку

# Минимальная и максимальная сумма чека
MIN_CHECK_AMOUNT = 100  # Минимум 100 VsCoin
MAX_CHECK_AMOUNT = 1000000  # Максимум 1,000,000 VsCoin

# Максимальное количество активаций (ограничено по сумме 1,000,000)
MAX_CHECK_ACTIVATIONS = 1000000  # Максимум активаций (ограничено суммарной суммой)

# Срок действия чека (дней)
CHECK_EXPIRY_DAYS = 30  # Чеки действительны 30 дней
# База данных
import os
import json
import datetime
import random
import time

class Database:
    def __init__(self, filename="db/users.json"):
        self.filename = filename
        self.data = {}
        self.promocodes = {}
        self.advertisements = {}
        self.ban_requests = {}
        self.helper_logs = {}
        self.checks = {}  # Система чеков
        self.check_books = {}  # Чековые книжки
        self.settings = {
            "bitcoin_rate": 500,
            "bitcoin_rate_percentage": 0,
            "helper_settings": {}
        }
        self.load()
    
    def load(self):
        """Загрузить все данные из файла"""
        if os.path.exists(self.filename):
            try:
                with open(self.filename, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.data = data.get('users', {})
                    self.promocodes = data.get('promocodes', {})
                    self.advertisements = data.get('advertisements', {})
                    self.ban_requests = data.get('ban_requests', {})
                    self.helper_logs = data.get('helper_logs', {})
                    self.checks = data.get('checks', {})
                    self.check_books = data.get('check_books', {})
                    self.settings = data.get('settings', self.settings)
                    
                    # Загрузка списка администраторов
                    global ADMIN_IDS
                    ADMIN_IDS = []
                    for user_id, user_data in self.data.items():
                        if user_data.get('is_admin', False):
                            ADMIN_IDS.append(int(user_id))
            except Exception as e:
                print(f"Ошибка загрузки БД: {e}")
                self.initialize_default_data()
        else:
            self.initialize_default_data()
    
    def initialize_default_data(self):
        """Инициализация всех данных по умолчанию"""
        self.data = {}
        self.promocodes = {}
        self.advertisements = {}
        self.ban_requests = {}
        self.helper_logs = {}
        self.checks = {}
        self.check_books = {}
        self.settings = {
            "bitcoin_rate": 500,
            "bitcoin_rate_percentage": 0,
            "helper_settings": {}
        }
        
        # Создаем директорию если не существует
        os.makedirs(os.path.dirname(self.filename), exist_ok=True)
    
    def save(self):
        """Сохранить все данные в файл"""
        data = {
            'users': self.data,
            'promocodes': self.promocodes,
            'advertisements': self.advertisements,
            'ban_requests': self.ban_requests,
            'helper_logs': self.helper_logs,
            'checks': self.checks,
            'check_books': self.check_books,
            'settings': self.settings
        }
        try:
            with open(self.filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
        except Exception as e:
            print(f"Ошибка сохранения БД: {e}")
    
    # ============ ОСНОВНЫЕ МЕТОДЫ ПОЛЬЗОВАТЕЛЕЙ ============
    
    def get_user(self, user_id):
        """Получить данные пользователя или создать нового"""
        user_id_str = str(user_id)
        if user_id_str not in self.data:
            self.data[user_id_str] = {
                "balance": 5000,
                "bitcoin_balance": 0,
                "games_played": 0,
                "wins": 0,
                "losses": 0,
                "won_amount": 0,
                "lost_amount": 0,
                "registration_date": datetime.datetime.now().strftime("%d-%m-%Y %H:%M"),
                "last_bonus": None,
                "status": "Игрок",
                "username": "",
                "banned": False,
                "ban_reason": "",
                "ban_until": "",
                "active_game": None,
                "is_admin": False,
                "helper_rank": 0,
                "business": None,
                "business_balance": 0,
                "business_last_updated": None,
                "completed_advertisements": [],
                "deposits": [],
                "credits": [],
                "reserved_balance": 0  # Для системы чеков
            }
            self.save()
        return self.data[user_id_str]
    
    def update_user(self, user_id, data):
        """Обновить данные пользователя"""
        user = self.get_user(user_id)
        user.update(data)
        self.save()
    
    # ============ СИСТЕМА ЧЕКОВ ============
    
    def has_checkbook(self, user_id):
        """Проверка наличия чековой книжки"""
        user_str = str(user_id)
        return user_str in self.check_books and self.check_books[user_str].get('is_active', False)
    
    def buy_checkbook(self, user_id):
        """Покупка чековой книжки"""
        user_data = self.get_user(user_id)
        user_str = str(user_id)
        
        if user_data['balance'] < CHECKBOOK_PRICE:
            return False, "❌ Недостаточно средств для покупки чековой книжки"
        
        # Списываем средства
        user_data['balance'] -= CHECKBOOK_PRICE
        
        # Создаем или обновляем чековую книжку
        if user_str not in self.check_books:
            self.check_books[user_str] = {
                'purchase_date': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                'total_checks_created': 0,
                'total_amount_issued': 0,
                'is_active': True
            }
        else:
            self.check_books[user_str]['is_active'] = True
        
        self.save()
        return True, f"✅ Чековая книжка куплена за {format_number(CHECKBOOK_PRICE)} VsCoin"
    
    def create_check(self, user_id, amount, activations):
        """Создание нового чека"""
        user_str = str(user_id)
        user_data = self.get_user(user_id)
        
        # Проверяем наличие чековой книжки
        if not self.has_checkbook(user_id):
            return None, "❌ У вас нет чековой книжки. Купите её через /check"
        
        # Проверяем минимальную и максимальную сумму
        if amount < MIN_CHECK_AMOUNT:
            return None, f"❌ Минимальная сумма чека: {MIN_CHECK_AMOUNT} VsCoin"
        if amount > MAX_CHECK_AMOUNT:
            return None, f"❌ Максимальная сумма чека: {MAX_CHECK_AMOUNT} VsCoin"
        
        # Проверяем количество активаций
        if activations < 1:
            return None, f"❌ Минимум 1 активация"
        
        # Проверяем общую сумму (максимум 1,000,000)
        total_amount = amount * activations
        if total_amount > 1000000:
            return None, f"❌ Максимальная общая сумма чека не может превышать 1,000,000 VsCoin"
        
        # Проверяем баланс
        if user_data['balance'] < total_amount:
            return None, f"❌ Недостаточно средств. Нужно: {total_amount} VsCoin"
        
        # Генерируем ID и номер чека
        check_id = f"CHK{int(datetime.datetime.now().timestamp())}{random.randint(1000, 9999)}"
        check_number = f"CHK{len(self.checks) + 1}"
        
        # Создаем чек
        self.checks[check_id] = {
            'id': check_id,
            'check_number': check_number,
            'creator_id': user_id,
            'creator_name': user_data.get('username', f'ID:{user_id}'),
            'amount': amount,
            'total_activations': activations,
            'used_activations': 0,
            'total_amount': total_amount,
            'activated_by': [],
            'activation_dates': [],
            'password': None,
            'description': None,
            'status': 'active',
            'created_date': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'expiry_date': None,
            'refund_amount': 0
        }
        
        # Резервируем средства
        user_data['balance'] -= total_amount
        user_data['reserved_balance'] = user_data.get('reserved_balance', 0) + total_amount
        
        # Обновляем статистику чековой книжки
        if user_str in self.check_books:
            self.check_books[user_str]['total_checks_created'] = self.check_books[user_str].get('total_checks_created', 0) + 1
            self.check_books[user_str]['total_amount_issued'] = self.check_books[user_str].get('total_amount_issued', 0) + total_amount
        
        self.save()
        return check_id, f"✅ Чек #{check_number} создан на сумму {format_number(amount)} × {activations}"
    
    def get_check(self, check_id):
        """Получить информацию о чеке"""
        return self.checks.get(check_id)
    
    def get_check_by_number(self, check_number):
        """Получить чек по номеру"""
        for check_id, check_data in self.checks.items():
            if check_data['check_number'] == check_number:
                return check_data
        return None
    
    def get_user_checks(self, user_id):
        """Получить все чеки пользователя"""
        user_checks = []
        for check_id, check_data in self.checks.items():
            if check_data['creator_id'] == user_id and check_data['status'] == 'active':
                user_checks.append((check_id, check_data))
        
        # Сортируем по дате создания (новые сначала)
        user_checks.sort(key=lambda x: x[1]['created_date'], reverse=True)
        return user_checks
    
    def set_check_password(self, check_id, password):
        """Установить пароль для чека"""
        if check_id in self.checks:
            self.checks[check_id]['password'] = password
            self.save()
            return True
        return False
    
    def set_check_description(self, check_id, description):
        """Установить описание для чека"""
        if check_id in self.checks:
            self.checks[check_id]['description'] = description
            self.save()
            return True
        return False
    
    def activate_check(self, check_id, user_id, password=None):
        """Активация чека (теперь можно активировать свой собственный чек)"""
        if check_id not in self.checks:
            return False, "❌ Чек не найден"
        
        check_data = self.checks[check_id]
        
        # Проверяем статус
        if check_data['status'] != 'active':
            return False, "❌ Этот чек уже не активен"
        
        # Проверяем количество активаций
        if check_data['used_activations'] >= check_data['total_activations']:
            check_data['status'] = 'completed'
            self.save()
            return False, "❌ Все активации этого чека уже использованы"
        
        # Проверяем пароль
        if check_data['password'] and check_data['password'] != password:
            return False, "❌ Неверный пароль"
        
        # Проверяем, не активировал ли уже пользователь
        if user_id in check_data['activated_by']:
            return False, "❌ Вы уже активировали этот чек"
        
        # Начисляем средства пользователю
        user_data = self.get_user(user_id)
        user_data['balance'] += check_data['amount']
        
        # Обновляем данные чека
        check_data['used_activations'] += 1
        check_data['activated_by'].append(user_id)
        check_data['activation_dates'].append(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        
        # Если активаций больше нет, помечаем как завершенный
        if check_data['used_activations'] >= check_data['total_activations']:
            check_data['status'] = 'completed'
        
        # Освобождаем зарезервированные средства у создателя
        creator_data = self.get_user(check_data['creator_id'])
        reserved_balance = creator_data.get('reserved_balance', 0)
        creator_data['reserved_balance'] = max(0, reserved_balance - check_data['amount'])
        
        # Обновляем баланс создателя (возвращаем неиспользованную часть)
        if check_data['status'] == 'completed':
            remaining_balance = creator_data['reserved_balance']
            creator_data['balance'] += remaining_balance
            creator_data['reserved_balance'] = 0
            check_data['refund_amount'] = remaining_balance
        
        self.save()
        
        return True, f"✅ Чек активирован! Получено {format_number(check_data['amount'])} VsCoin"
    
    def delete_check(self, check_id, user_id):
        """Удаление чека"""
        if check_id not in self.checks:
            return False, "❌ Чек не найден"
        
        check_data = self.checks[check_id]
        
        # Проверяем права
        if check_data['creator_id'] != user_id:
            return False, "❌ Вы не являетесь создателем этого чека"
        
        # Вычисляем сумму к возврату
        remaining_activations = check_data['total_activations'] - check_data['used_activations']
        refund_amount = remaining_activations * check_data['amount']
        
        # Возвращаем средства создателю
        user_data = self.get_user(user_id)
        user_data['balance'] += refund_amount
        
        # Уменьшаем зарезервированный баланс
        reserved_balance = user_data.get('reserved_balance', 0)
        user_data['reserved_balance'] = max(0, reserved_balance - refund_amount)
        
        # Помечаем чек как отмененный
        check_data['status'] = 'cancelled'
        check_data['refund_amount'] = refund_amount
        
        self.save()
        return True, f"✅ Чек удален. Возвращено {format_number(refund_amount)} VsCoin"
    
    # ============ ОСТАЛЬНЫЕ МЕТОДЫ ============
    
    def get_top_users(self, limit=10):
        """Получить топ пользователей по балансу"""
        users = [(uid, data) for uid, data in self.data.items() 
                if not data.get("banned", False) and not data.get("is_admin", False)]
        sorted_users = sorted(users, key=lambda x: x[1]["balance"], reverse=True)
        return sorted_users[:limit]
    
    def add_promocode(self, code, amount, uses=1):
        """Добавить промокод"""
        self.promocodes[code] = {
            'amount': amount, 
            'uses': uses, 
            'used_by': [],
            'created_at': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'created_by': None
        }
        self.save()
    
    def use_promocode(self, code, user_id):
        """Использовать промокод"""
        if code in self.promocodes:
            promocode = self.promocodes[code]
            if user_id not in promocode['used_by'] and len(promocode['used_by']) < promocode['uses']:
                promocode['used_by'].append(user_id)
                self.save()
                return promocode['amount']
        return 0
    
    def add_advertisement(self, task_id, channel, bitcoin_reward):
        """Добавить рекламное задание"""
        self.advertisements[task_id] = {
            'channel': channel,
            'bitcoin_reward': bitcoin_reward
        }
        self.save()
    
    def remove_advertisement(self, task_id):
        """Удалить рекламное задание"""
        if task_id in self.advertisements:
            del self.advertisements[task_id]
            self.save()
            return True
        return False
    
    def get_all_promocodes(self):
        """Получить все промокоды"""
        return self.promocodes
    
    def get_all_advertisements(self):
        """Получить все рекламные задания"""
        return self.advertisements
    
    def get_active_games(self):
        """Получить активные игры"""
        active_games = []
        for user_id, user_data in self.data.items():
            if user_data.get('active_game'):
                active_games.append({
                    'user_id': user_id,
                    'username': user_data.get('username', 'Unknown'),
                    'game': user_data['active_game']
                })
        return active_games
    
    # Хелпер система
    def set_helper_rank(self, user_id, rank):
        """Установить ранг помощника"""
        user_data = self.get_user(user_id)
        user_data['helper_rank'] = rank
        if rank > 0:
            user_data['status'] = f"Хелпер {rank}"
        else:
            user_data['status'] = "Игрок"
        self.save()
    
    def log_helper_action(self, helper_id, action_type, details):
        """Записать действие помощника в лог"""
        log_id = str(int(time.time()))
        self.helper_logs[log_id] = {
            'helper_id': helper_id,
            'action_type': action_type,
            'details': details,
            'timestamp': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        self.save()
    
    def create_ban_request(self, requester_id, target_id, days, reason):
        """Создать заявку на бан"""
        request_id = str(int(time.time()))
        requester_data = self.get_user(requester_id)
        target_data = self.get_user(target_id)
        
        self.ban_requests[request_id] = {
            'id': request_id,
            'requester_id': requester_id,
            'requester_name': requester_data.get('username', f'ID:{requester_id}'),
            'target_id': target_id,
            'target_name': target_data.get('username', f'ID:{target_id}'),
            'days': days,
            'reason': reason,
            'status': 'pending',
            'processed_by': None,
            'created_at': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'processed_at': None
        }
        self.save()
        return request_id
    
    def get_pending_ban_requests(self):
        """Получить ожидающие заявки на бан"""
        return [req for req in self.ban_requests.values() if req['status'] == 'pending']
    
    def approve_ban_request(self, request_id, processor_id):
        """Одобрить заявку на бан"""
        if request_id in self.ban_requests:
            request = self.ban_requests[request_id]
            target_id = request['target_id']
            days = request['days']
            reason = request['reason']
            
            # Баним пользователя
            target_data = self.get_user(target_id)
            target_data['banned'] = True
            target_data['ban_reason'] = reason
            ban_until = datetime.datetime.now() + datetime.timedelta(days=days)
            target_data['ban_until'] = ban_until.strftime("%d-%m-%Y %H:%M:%S")
            
            # Обновляем заявку
            request['status'] = 'approved'
            request['processed_by'] = processor_id
            request['processed_at'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            self.save()
            return True
        return False
    
    def reject_ban_request(self, request_id, processor_id):
        """Отклонить заявку на бан"""
        if request_id in self.ban_requests:
            request = self.ban_requests[request_id]
            request['status'] = 'rejected'
            request['processed_by'] = processor_id
            request['processed_at'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            self.save()
            return True
        return False
    
    def get_banned_users(self):
        """Получить забаненных пользователей"""
        return [(uid, data) for uid, data in self.data.items() if data.get('banned', False)]
    
    def unban_user(self, user_id):
        """Разбанить пользователя"""
        user_data = self.get_user(user_id)
        user_data['banned'] = False
        user_data['ban_reason'] = ''
        user_data['ban_until'] = ''
        self.save()
    
    def get_pending_credit_requests(self):
        """Получить ожидающие кредитные заявки"""
        pending = []
        for user_id, user_data in self.data.items():
            for credit in user_data.get('credits', []):
                if credit.get('status') == 'pending':
                    pending.append({
                        'user_id': int(user_id),
                        'user_data': user_data,
                        'credit_data': credit
                    })
        return pending
    
    def approve_credit_request(self, user_id, amount, term, processor_id):
        """Одобрить кредитную заявку"""
        user_data = self.get_user(user_id)
        
        for credit in user_data.get('credits', []):
            if (credit['amount'] == amount and 
                credit['term'] == term and 
                credit['status'] == 'pending'):
                
                credit['status'] = 'approved'
                credit['approval_date'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                credit['approved_by'] = processor_id
                user_data['balance'] += amount
                
                self.save()
                return True
        return False
    
    def get_statistics(self):
        """Получить статистику для панели хелперов"""
        total_users = len(self.data)
        total_balance = sum(user.get('balance', 0) for user in self.data.values())
        total_games = sum(user.get('games_played', 0) for user in self.data.values())
        
        helpers = sum(1 for user in self.data.values() if user.get('helper_rank', 0) > 0)
        banned = sum(1 for user in self.data.values() if user.get('banned', False))
        pending_bans = len(self.get_pending_ban_requests())
        pending_credits = len(self.get_pending_credit_requests())
        
        return {
            'total_users': total_users,
            'total_balance': total_balance,
            'total_games': total_games,
            'helpers': helpers,
            'banned': banned,
            'pending_bans': pending_bans,
            'pending_credits': pending_credits
        }
    
    def cleanup_old_ban_requests(self, days_old=30):
        """Очистить старые заявки на бан"""
        now = datetime.datetime.now()
        to_delete = []
        
        for request_id, request in self.ban_requests.items():
            if request['status'] in ['approved', 'rejected']:
                try:
                    processed_at = datetime.datetime.strptime(request['processed_at'], "%Y-%m-%d %H:%M:%S")
                    if (now - processed_at).days > days_old:
                        to_delete.append(request_id)
                except:
                    pass
        
        for request_id in to_delete:
            del self.ban_requests[request_id]
        
        if to_delete:
            self.save()
        
        return len(to_delete)
    
    def cleanup_old_helper_logs(self, days_old=90):
        """Очистить старые логи помощников"""
        now = datetime.datetime.now()
        to_delete = []
        
        for log_id, log in self.helper_logs.items():
            try:
                timestamp = datetime.datetime.strptime(log['timestamp'], "%Y-%m-%d %H:%M:%S")
                if (now - timestamp).days > days_old:
                    to_delete.append(log_id)
            except:
                pass
        
        for log_id in to_delete:
            del self.helper_logs[log_id]
        
        if to_delete:
            self.save()
        
        return len(to_delete)
    
    def get_user_by_username(self, username):
        """Найти пользователя по username"""
        for user_id, user_data in self.data.items():
            if user_data.get('username', '').lower() == username.lower():
                return int(user_id), user_data
        return None, None
    
    def get_helper_logs(self, helper_id=None, limit=50):
        """Получить логи помощников"""
        logs = list(self.helper_logs.values())
        
        if helper_id:
            logs = [log for log in logs if log['helper_id'] == helper_id]
        
        # Сортировка по времени (новые сначала)
        logs.sort(key=lambda x: x['timestamp'], reverse=True)
        
        return logs[:limit]
    
    def get_user_statistics(self, user_id):
        """Получить статистику пользователя"""
        user_data = self.get_user(user_id)
        
        return {
            'balance': user_data.get('balance', 0),
            'games_played': user_data.get('games_played', 0),
            'wins': user_data.get('wins', 0),
            'losses': user_data.get('losses', 0),
            'won_amount': user_data.get('won_amount', 0),
            'lost_amount': user_data.get('lost_amount', 0),
            'bitcoin_balance': user_data.get('bitcoin_balance', 0),
            'banned': user_data.get('banned', False),
            'helper_rank': user_data.get('helper_rank', 0),
            'is_admin': user_data.get('is_admin', False),
            'registration_date': user_data.get('registration_date', 'Unknown'),
            'business': user_data.get('business'),
            'deposits_count': len(user_data.get('deposits', [])),
            'credits_count': len(user_data.get('credits', []))
        }
    
    def backup_database(self, backup_dir="backups"):
        """Создать резервную копию базы данных"""
        try:
            os.makedirs(backup_dir, exist_ok=True)
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = os.path.join(backup_dir, f"backup_{timestamp}.json")
            
            data = {
                'users': self.data,
                'promocodes': self.promocodes,
                'advertisements': self.advertisements,
                'ban_requests': self.ban_requests,
                'helper_logs': self.helper_logs,
                'checks': self.checks,
                'check_books': self.check_books,
                'settings': self.settings,
                'backup_date': timestamp
            }
            
            with open(backup_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            
            return backup_file
        except Exception as e:
            print(f"Ошибка создания бэкапа: {e}")
            return None

# Создаем глобальный экземпляр базы данных
db = Database()

def format_number(num):
    if num >= 1000000000:
        return f"{num/1000000000:.2f}B".replace('.', ',')
    elif num >= 1000000:
        return f"{num/1000000:.2f}M".replace('.', ',')
    elif num >= 1000:
        return f"{num/1000:.1f}K".replace('.', ',')
    return str(num)

def parse_bet(text, user_balance=None):
    text = text.lower().replace(' ', '').replace(',', '.')
    
    if text == 'все' or text == 'all':
        return user_balance if user_balance is not None else 0
    
    if 'кк' in text:
        num = float(text.replace('кк', '')) * 1000000
    elif 'к' in text:
        num = float(text.replace('к', '')) * 1000
    elif 'b' in text:
        num = float(text.replace('b', '')) * 1000000000
    elif 'm' in text:
        num = float(text.replace('m', '')) * 1000000
    elif 'k' in text:
        num = float(text.replace('k', '')) * 1000
    else:
        try:
            num = float(text)
        except ValueError:
            return 0
    
    return int(num)


def require_same_user(func):
    """Декоратор для проверки, что пользователь взаимодействует со своим контентом"""
    @wraps(func)
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE, *args, **kwargs):
        query = update.callback_query if hasattr(update, 'callback_query') else None
        
        if not query:
            return await func(update, context, *args, **kwargs)
        
        user = query.from_user
        callback_data = query.data
        
        # Проверяем, содержит ли callback_data user_id
        if '_user_' in callback_data:
            # Извлекаем user_id из callback_data
            parts = callback_data.split('_user_')
            if len(parts) == 2:
                callback_user_id = int(parts[1].split('_')[0]) if parts[1].split('_')[0].isdigit() else None
                if callback_user_id and callback_user_id != user.id:
                    await query.answer("❌ Это не ваша кнопка!", show_alert=True)
                    return
        
        # Для кнопок, которые не содержат user_id, проверяем другими способами
        elif callback_data.startswith('balance_'):
            # Для баланса проверяем, что пользователь не нажимает чужую кнопку
            # Ищем сообщение, к которому привязана кнопка
            message_text = query.message.text if query.message else ""
            if f"tg://user?id={user.id}" not in message_text and str(user.id) not in message_text:
                await query.answer("❌ Это не ваша кнопка!", show_alert=True)
                return
        
        elif callback_data.startswith('help_'):
            # Помощь доступна всем
            pass
        
        elif callback_data.startswith(('mines_', 'gold_', 'tower_', 'pyramid_', 'chest_', 
                                     'twentyone_', 'basketball_', 'duel_')):
            # Для игр в БД проверяем активную игру
            user_data = db.get_user(user.id)
            game_type_map = {
                'mines': 'mines',
                'gold': 'gold',
                'tower': 'tower',
                'pyramid': 'pyramid',
                'chest': 'chest',
                'twentyone': 'twentyone',
                'basketball': 'basketball',
                'duel': 'duel'
           
            }
            
            for prefix, game_type in game_type_map.items():
                if callback_data.startswith(prefix):
                    if not user_data.get('active_game') or user_data['active_game'].get('type') != game_type:
                        await query.answer("❌ Это не ваша игра или игра завершена!", show_alert=True)
                        return
                    break
        
        elif callback_data.startswith(('hilo_', 'fb_choice_', 'fb_final_')):
            # Для игр в context.user_data
            parts = callback_data.split('_')
            if len(parts) > 3:
                game_key = '_'.join(parts[2:])
                if game_key in context.user_data:
                    game_data = context.user_data.get(game_key)
                    if game_data and game_data.get('user_id') != user.id:
                        await query.answer("❌ Это не ваша игра!", show_alert=True)
                        return
        
        elif callback_data.startswith(('earn_', 'check_sub_', 'exchange_', 'biz_', 
                                     'bank_', 'deposit_', 'credit_')):
            # Эти кнопки должны быть защищены user_id
            # Но пока просто разрешаем (позже добавим защиту)
            pass
        
        elif callback_data.startswith('admin_'):
            # Админка доступна только админам
            user_data = db.get_user(user.id)
            if not user_data.get('is_admin', False):
                await query.answer("❌ У вас нет прав!", show_alert=True)
                return
        
        elif callback_data.startswith('rps_'):
            if callback_data.startswith('rps_choice_'):
                parts = callback_data.split('_')
                if len(parts) > 2:
                    game_id = '_'.join(parts[2:])
                    if hasattr(context.bot_data, 'rps_games') and game_id in context.bot_data.rps_games:
                        game_data = context.bot_data.rps_games[game_id]
                        if user.id not in [game_data['challenger_id'], game_data['opponent_id']]:
                            await query.answer("❌ Вы не участник этой игры!", show_alert=True)
                            return
            elif callback_data.startswith(('rps_accept_', 'rps_decline_')):
                parts = callback_data.split('_')
                if len(parts) > 2:
                    challenge_id = parts[2]
                    if hasattr(context.bot_data, 'rps_challenges') and challenge_id in context.bot_data.rps_challenges:
                        challenge = context.bot_data.rps_challenges[challenge_id]
                        if user.id != challenge['opponent_id']:
                            await query.answer("❌ Этот вызов не для вас!", show_alert=True)
                            return
        
        # Общие кнопки
        elif callback_data in ['refresh_top', 'game_rules', 'mines_finished', 
                              'duel_finished', 'tower_finished']:
            pass
        
        return await func(update, context, *args, **kwargs)
    return wrapper

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда /start - начало работы с ботом"""
    user = update.effective_user
    
    # Получаем или создаем пользователя в базе данных
    user_data = db.get_user(user.id)
    user_data['username'] = user.username or user.full_name
    db.update_user(user.id, user_data)
    
    # Проверяем, есть ли аргументы
    if context.args and len(context.args) > 0:
        arg = context.args[0]
        
        # Проверяем, активируется ли чек (формат: check_CHK123 или check_12345)
        if arg.startswith('check_'):
            check_id = arg.replace('check_', '')
            
            # Проверяем существование чека
            check_data = None
            
            # Сначала пробуем найти по номеру (CHK123)
            if check_id.startswith('CHK'):
                check_data = db.get_check_by_number(check_id)
            
            # Если не нашли по номеру, пробуем найти по ID
            if not check_data:
                check_data = db.get_check(check_id)
            
            if not check_data:
                # Если чек не найден
                await update.message.reply_text(
                    f"💎 <b>Чек не найден</b>\n\n"
                    f"❌ Этот чек был удален, уже активирован или срок его действия истек.",
                    parse_mode=ParseMode.HTML
                )
                return
            
            # Проверяем статус
            if check_data['status'] != 'active':
                await update.message.reply_text("❌ Этот чек уже был активирован или удален")
                return
            
            # Проверяем, не активировал ли уже пользователь
            if user.id in check_data['activated_by']:
                await update.message.reply_text("⚠️ Вы уже активировали этот чек")
                return
            
            # Формируем текст чека
            check_text = f"💎 <b>Чек на {format_number(check_data['amount'])} VsCoin</b>\n\n"
            
            # Добавляем описание только если оно есть
            if check_data.get('description'):
                check_text += f"💬 {check_data['description']}\n\n"
            
            # Добавляем информацию об активациях
            remaining = check_data['total_activations'] - check_data['used_activations']
            check_text += f"🔘 Осталось активаций: {remaining}/{check_data['total_activations']}\n\n"
            
            check_text += "Нажмите кнопку ниже, чтобы активировать чек"
            
            # Создаем кнопку активации
            keyboard = [[InlineKeyboardButton("✅ Активировать", callback_data=f"check_activate_{check_data['id']}")]]
            
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                check_text,
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
            return
        
        # Проверяем, редактируется ли чек
        elif arg.startswith('editcheck_'):
            check_id = arg.replace('editcheck_', '')
            
            # Находим чек
            check_data = db.get_check(check_id)
            if not check_data:
                # Если не нашли по ID, пробуем найти по номеру
                check_data = db.get_check_by_number(check_id)
            
            if check_data:
                if check_data['creator_id'] != user.id:
                    await update.message.reply_text("❌ Вы не являетесь создателем этого чека")
                    return
                
                # Показываем меню редактирования с правильной ссылкой
                check_link = f"https://t.me/qmines_Bot?start=check_{check_data['check_number']}"
                text = (
                    f"✏️ <b>РЕДАКТИРОВАТЬ ЧЕК #{check_data['check_number']}</b>\n"
                    f"·····················\n"
                    f"💰 Сумма за активацию: {format_number(check_data['amount'])} Vscoin\n"
                    f"🔘 Активаций: {check_data['used_activations']}/{check_data['total_activations']}\n"
                )
                
                if check_data.get('description'):
                    text += f"📝 Описание: {check_data['description']}\n"
                else:
                    text += f"📝 Описание: нет\n"
                
                if check_data.get('password'):
                    text += f"🔐 Пароль: установлен\n"
                else:
                    text += f"🔐 Пароль: нет\n"
                
                text += f"🔗 Ссылка: <code>{check_link}</code>\n\n"
                text += "Выберите действие:"
                
                keyboard = [
                    [InlineKeyboardButton("📝 Изменить описание", callback_data=f"check_setdesc_{check_data['id']}")],
                    [InlineKeyboardButton("🔐 Установить/изменить пароль", callback_data=f"check_setpass_{check_data['id']}")],
                    [InlineKeyboardButton("📋 Скопировать ссылку", callback_data=f"check_copy_{check_data['id']}")],
                    [InlineKeyboardButton("🗑 Удалить чек", callback_data=f"check_delete_{check_data['id']}")],
                    [InlineKeyboardButton("🔙 В меню", callback_data="check_back")]
                ]
                
                reply_markup = InlineKeyboardMarkup(keyboard)
                
                await update.message.reply_text(
                    text,
                    parse_mode=ParseMode.HTML,
                    reply_markup=reply_markup
                )
                return
            else:
                await update.message.reply_text("❌ Чек не найден")
                return
        
        # Проверяем промокод
        else:
            code = arg
            
            # Проверяем промокод
            reward = db.use_promocode(code, user.id)
            
            if reward > 0:
                user_data['balance'] += reward
                db.update_user(user.id, user_data)
                
                await update.message.reply_text(
                    f"✅ Промокод активирован!\n"
                    f"💰 Получено: {format_number(reward)} VsCoin\n"
                    f"💳 Ваш баланс: {format_number(user_data['balance'])} VsCoin",
                    parse_mode=ParseMode.HTML
                )
                return
            else:
                # Если не промокод, показываем сообщение
                await update.message.reply_text(
                    f"❌ Промокод '{code}' не найден или уже был использован\n\n"
                    f"Напишите /help для получения списка команд",
                    parse_mode=ParseMode.HTML
                )
                return
    
    # Если нет аргументов или аргумент не распознан, показываем стандартное приветствие
    welcome_text = (
        "Привет я Vmines Bot\n\n"
        "⚡️ Скоротай время со мной и получи максимум выгоды!\n"
        "С помощью моих игр ты можешь не только развлечься, но и прокачать активность в своём канале или чате. Играй в одиночку, с друзьями или семьёй — скучно точно не будет! 🎮\n\n"
        "🔥 Что можно сделать прямо сейчас?\n"
        "Просто напиши /game — и мы начнём! А если хочешь узнать больше о моих возможностях, команда /help тебе всё расскажет. 😉\n\n"
        "🎯 Готов к первому ходу? Давай сыграем!"
    )
    
    keyboard = [
        [InlineKeyboardButton("Наш ТГ", url="https://t.me/vsmines"),
        InlineKeyboardButton("Поддержка", url="https://t.me/Vadim_Speen")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(welcome_text, reply_markup=reply_markup)

# Также нужно обновить функцию show_user_checks_menu для правильных ссылок:


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    # Создаем клавиатуру с кнопками
    keyboard = [
        [InlineKeyboardButton("📋 Основные команды", callback_data="help_main")],
        [InlineKeyboardButton("🎮 Игровые команды", callback_data="help_games")],
        [InlineKeyboardButton("📜 Правила", url="https://telegra.ph/VminesBot-12-23-2")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    help_text = (
        "📖 <b>Помощь по боту</b>\n\n"
        "Выберите раздел помощи:"
    )
    
    await update.message.reply_text(help_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def help_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    data = query.data
    
    if data == "help_main":
        main_commands_text = (
            "📋 <b>Основные команды:</b>\n\n"
            "профиль - Ваш профиль\n"
            "баланс - Ваш баланс\n"
            "бонус - Ежедневный бонус\n"
            "топ - Топ игроков\n"
            "перевести [сумма] [@username] - Перевести деньги\n"
            "промо [код] - Активировать промокод\n"
            "заработать - Заработать биткоины\n"
            "обменник - P2P обменник биткоинов\n"
            "бизнес - Покупка бизнеса\n"
            "управлениебизнесом - Управление бизнесом\n"
            "банк - Банковские операции\n"
            "кредит - Погасить кредит"
        )
        
        keyboard = [[InlineKeyboardButton("◀️ Назад", callback_data="help_back")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(main_commands_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
    
    elif data == "help_games":
        games_commands_text = (
            "🎮 <b>Игровые команды:</b>\n\n"
            "мины [ставка] [количество мин] - Игра в мины\n"
            "футбол [ставка] - Футбол\n"
            "баскетбол [ставка] - Баскетбол\n"
            "золото [ставка] - Игра в золото\n"
            "рулетка [ставка] [цвет/число] - Рулетка\n"
            "21 [ставка] - Игра 21\n"
            "кости [ставка] [число] - Игра в кости\n"
            "на все - Игра на все\n"
            "башня [ставка] [количество мин] - Игра в башню\n"
            "пирамида [ставка] [количество петард] - Игра в пирамиду\n"
            "хило [ставка] - Игра Хило\n"
            "сундук [ставка] - Игра в сундук\n"
            "дуэль [ставка] [количество мин] - Дуэль с другим игроком\n"
            "кнб [ставка] - Камень-ножницы-бумага с другим игроком\n\n"
            "ℹ️ <b>Для игр с другим игроком нужно ответить на его сообщение командой</b>"
        )
        
        keyboard = [[InlineKeyboardButton("◀️ Назад", callback_data="help_back")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(games_commands_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
    
    elif data == "help_back":
        keyboard = [
            [InlineKeyboardButton("📋 Основные команды", callback_data="help_main")],
            [InlineKeyboardButton("🎮 Игровые команды", callback_data="help_games")],
            [InlineKeyboardButton("📜 Правила", url="https://telegra.ph/VminesBot-12-23-2")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        help_text = "📖 <b>Помощь по боту</b>\n\nВыберите раздел помощи:"
        await query.edit_message_text(help_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
    
    await query.answer()
async def profile(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    top_users = db.get_top_users(10000)
    user_rank = next((i+1 for i, (uid, _) in enumerate(top_users) if uid == str(user.id)), 99999)
    
    business_name = user_data.get('business', 'Нету')
    if business_name != 'Нету':
        business_info = BUSINESSES.get(business_name, {})
        business_name = business_info.get('name', 'Нету')
    
    profile_text = (
        f"🆔 Профиль: {user.id}\n"
        "·····················\n"
        f"├ 👤 {user.full_name}\n"
        f"├ ⚡️ Статус: {user_data['status']}\n"
        f"├ 🎮 Сыграно игр: {format_number(user_data['games_played'])}\n"
        f"├ 🏆 Место в топе: {format_number(user_rank)}\n"
        f"├ 🟢 Выиграно: {format_number(user_data['won_amount'])} Vscoin\n"
        f"├ 📉 Проиграно: {format_number(user_data['lost_amount'])} Vscoin\n"
        f"├ 🪙 Биткоины: {user_data.get('bitcoin_balance', 0)}\n"
        f"├ 🏢 Бизнес: {business_name}\n"
        f"📅 Дата регистрации: {user_data['registration_date']}\n"
        "·····················\n"
        f"💰 Баланс: {format_number(user_data['balance'])} Vscoin"
    )
    
    await update.message.reply_text(profile_text)

async def balance(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    balance_text = (
        f"💰Баланс: {format_number(user_data['balance'])} Vscoin\n"
        f"🪙Биткоины: {user_data.get('bitcoin_balance', 0)}\n"
        "·····················\n"
        f"💣 Сыграно игр: {format_number(user_data['games_played'])}\n"
        f"🗿 Проиграно Vscoin: {format_number(user_data['lost_amount'])}"
    )
    
    # Проверяем доступность бонуса (теперь 1 час)
    now = datetime.datetime.now()
    can_get_bonus = True
    
    if user_data['last_bonus']:
        last_bonus = datetime.datetime.strptime(user_data['last_bonus'], "%Y-%m-%d %H:%M:%S")
        time_diff = now - last_bonus
        
        if time_diff.total_seconds() < 3600:  # 1 час
            can_get_bonus = False
            next_bonus = last_bonus + datetime.timedelta(hours=1)
            time_left = next_bonus - now
            minutes = time_left.seconds // 60
            seconds = time_left.seconds % 60
            
            balance_text += f"\n·····················\n⏳ Следующий бонус через: {minutes} мин {seconds} сек"
    
    keyboard = [
        [InlineKeyboardButton("🎁 Бонус", callback_data="balance_bonus")] if can_get_bonus else [],
        [InlineKeyboardButton("🪙 Заработать", callback_data="balance_earn")]
    ]
    # Убираем пустые строки
    keyboard = [row for row in keyboard if row]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(balance_text, reply_markup=reply_markup)

# 4. Обновите обработчик кнопки бонуса в балансе:
async def balance_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    
    if query.data == "balance_bonus":
        user_data = db.get_user(user.id)
        
        # Проверяем доступность бонуса (1 час)
        now = datetime.datetime.now()
        
        if user_data['last_bonus']:
            last_bonus = datetime.datetime.strptime(user_data['last_bonus'], "%Y-%m-%d %H:%M:%S")
            time_diff = now - last_bonus
            
            if time_diff.total_seconds() < 3600:  # 1 час
                next_bonus = last_bonus + datetime.timedelta(hours=1)
                time_left = next_bonus - now
                minutes = time_left.seconds // 60
                seconds = time_left.seconds % 60
                
                await query.answer(
                    f"⏳ Бонус можно получить через {minutes} мин {seconds} сек", 
                    show_alert=True
                )
                return
        
        # Выдаем бонус
        bonus_amount = random.randint(BONUS_AMOUNT[0], BONUS_AMOUNT[1])
        user_data['balance'] += bonus_amount
        user_data['last_bonus'] = now.strftime("%Y-%m-%d %H:%M:%S")
        db.update_user(user.id, user_data)
        
        # Обновляем сообщение
        balance_text = (
            f"💰Баланс: {format_number(user_data['balance'])} Vscoin\n"
            f"🪙Биткоины: {user_data.get('bitcoin_balance', 0)}\n"
            "·····················\n"
            f"💣 Сыграно игр: {format_number(user_data['games_played'])}\n"
            f"🗿 Проиграно Vscoin: {format_number(user_data['lost_amount'])}\n"
            "·····················\n"
            f"🎉 Получен бонус: {format_number(bonus_amount)} Vscoin!\n"
            f"⏰ Следующий бонус через 1 час"
        )
        
        # Обновляем клавиатуру (убираем кнопку бонуса)
        keyboard = [[InlineKeyboardButton("🪙 Заработать биткоины", callback_data="balance_earn")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(balance_text, reply_markup=reply_markup)
        await query.answer(f"🎁 Бонус: {format_number(bonus_amount)} Vscoin!")
        
    elif query.data == "balance_earn":
        fake_update = Update(update.update_id, message=query.message)
        await earn_command(fake_update, context)
       
  

        await query.answer()
    # Не вызываем query.answer() здесь, так как он уже вызван выше

async def bonus(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    now = datetime.datetime.now()
    
    # Проверяем, получал ли пользователь бонус в последний час
    if user_data.get('last_bonus'):
        last_bonus = datetime.datetime.strptime(user_data['last_bonus'], "%Y-%m-%d %H:%M:%S")
        time_diff = now - last_bonus
        
        if time_diff.total_seconds() < 3600:  # 1 час = 3600 секунд
            # Вычисляем время до следующего бонуса
            next_bonus = last_bonus + datetime.timedelta(hours=1)
            time_left = next_bonus - now
            minutes = time_left.seconds // 60
            seconds = time_left.seconds % 60
            
            # Считаем сколько всего бонусов собрано
            total_bonuses = user_data.get('total_bonuses', 0)
            
            # Формируем сообщение
            message = (
                f"🎁 <a href='tg://user?id={user.id}'>{user.full_name}</a>, ты уже получил свой бонус!\n"
                f"Всего собрано: {total_bonuses}\n"
                f"Приходи через {minutes} м. {seconds} с. ⏳\n"
                f"·····················\n"
                f"💰Баланс: {format_number(user_data['balance'])} Vscoin\n\n"
                f"ℹ️ Также ты можешь собрать следующие бонусы 👇"
            )
            
            # Создаем кнопку для ежедневного бонуса
            keyboard = [[InlineKeyboardButton("🎁 Ежедневный бонус", callback_data="daily_bonus")]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                message,
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup,
                disable_web_page_preview=True
            )
            return
    
    # Если бонус можно получить
    bonus_amount = random.randint(BONUS_AMOUNT[0], BONUS_AMOUNT[1])
    user_data['balance'] += bonus_amount
    user_data['last_bonus'] = now.strftime("%Y-%m-%d %H:%M:%S")
    
    # Обновляем счетчик бонусов
    total_bonuses = user_data.get('total_bonuses', 0) + 1
    user_data['total_bonuses'] = total_bonuses
    
    db.update_user(user.id, user_data)
    
    # Формируем сообщение о получении бонуса
    message = (
        f"🎁 <a href='tg://user?id={user.id}'>{user.full_name}</a>, тебе был выдан бонус в размере: {format_number(bonus_amount)} Vscoin!\n"
        f"·····················\n"
        f"💰Баланс: {format_number(user_data['balance'])} Vscoin\n\n"
        f"ℹ️ Также ты можешь собрать следующие бонусы 👇"
    )
    
    # Создаем кнопку для ежедневного бонуса
    keyboard = [[InlineKeyboardButton("🎁 Ежедневный бонус", callback_data="daily_bonus")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        message,
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        disable_web_page_preview=True
    )

async def daily_bonus_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопки ежедневного бонуса"""
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    user_data = db.get_user(user.id)
    
    # Проверяем, получал ли пользователь ежедневный бонус сегодня
    now = datetime.datetime.now()
    today = now.strftime("%Y-%m-%d")
    
    last_daily_bonus = user_data.get('last_daily_bonus', '')
    
    if last_daily_bonus == today:
        # Уже получал бонус сегодня
        await query.edit_message_text(
            f"🎁 <a href='tg://user?id={user.id}'>{user.full_name}</a>, ты уже получил ежедневный бонус сегодня!\n"
            f"Приходи завтра за новым бонусом ⏳\n"
            f"·····················\n"
            f"💰Баланс: {format_number(user_data['balance'])} Vscoin",
            parse_mode=ParseMode.HTML,
            disable_web_page_preview=True
        )
        return
    
    # Создаем игру с РАНДОМНЫМИ призами в каждой ячейке
    # Каждая ячейка получает случайный приз из списка [1000, 2500, 5000]
    prizes = []
    possible_prizes = [1000, 2500, 5000]
    
    for i in range(3):
        # Для каждой ячейки выбираем случайный приз
        prize = random.choice(possible_prizes)
        prizes.append(prize)
    
    # Сохраняем призы в БД пользователя
    user_data['daily_bonus_prizes'] = prizes
    db.update_user(user.id, user_data)
    
    # Создаем кнопки с сейфами
    keyboard = [
        [
            InlineKeyboardButton("💼", callback_data="daily_cell_0"),
            InlineKeyboardButton("💼", callback_data="daily_cell_1"),
            InlineKeyboardButton("💼", callback_data="daily_cell_2")
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"🎁 <a href='tg://user?id={user.id}'>{user.full_name}</a>, выбери один сейф!\n"
        f"В каждом сейфе РАНДОМНЫЙ приз!\n"
        f"·····················\n"
        f"💰Баланс: {format_number(user_data['balance'])} Vscoin",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        disable_web_page_preview=True
    )

async def daily_cell_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик выбора ячейки"""
    query = update.callback_query
    data = query.data
    
    await query.answer()
    
    # Получаем индекс выбранной ячейки
    cell_index = int(data.split('_')[2])
    
    user = query.from_user
    user_data = db.get_user(user.id)
    
    # Проверяем, получал ли уже бонус сегодня
    now = datetime.datetime.now()
    today = now.strftime("%Y-%m-%d")
    
    last_daily_bonus = user_data.get('last_daily_bonus', '')
    
    if last_daily_bonus == today:
        await query.answer("❌ Вы уже получили ежедневный бонус сегодня!")
        return
    
    # Получаем сохраненные призы из БД
    prizes = user_data.get('daily_bonus_prizes', [])
    
    # Если призы не найдены, генерируем новые РАНДОМНЫЕ
    if not prizes or len(prizes) != 3:
        possible_prizes = [1000, 2500, 5000]
        prizes = []
        for i in range(3):
            prizes.append(random.choice(possible_prizes))
    
    # Получаем приз из выбранной ячейки
    if cell_index < 0 or cell_index >= len(prizes):
        await query.answer("❌ Ошибка: неверная ячейка")
        return
    
    prize = prizes[cell_index]
    
    # Начисляем приз пользователю
    user_data['balance'] += prize
    user_data['last_daily_bonus'] = today
    
    # Очищаем призы из БД
    user_data['daily_bonus_prizes'] = []
    
    db.update_user(user.id, user_data)
    
    # Создаем обновленные кнопки
    keyboard_buttons = []
    for i in range(3):
        if i == cell_index:
            # Показываем выбранную ячейку с призом
            keyboard_buttons.append(InlineKeyboardButton(f"{prize} Vscoin", callback_data="daily_finished"))
        else:
            # Показываем другие ячейки закрытыми
            keyboard_buttons.append(InlineKeyboardButton("💼", callback_data="daily_finished"))
    
    keyboard = [keyboard_buttons]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Отправляем результат
    await query.edit_message_text(
        f"🎉 <a href='tg://user?id={user.id}'>{user.full_name}</a>, ты успешно получил ежедневный бонус!\n"
        f"В ячейке лежало: {format_number(prize)} Vscoin\n"
        f"·····················\n"
        f"💰Баланс: {format_number(user_data['balance'])} Vscoin",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        disable_web_page_preview=True
    )



async def top(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    # Обновляем username текущего пользователя в БД
    user_data = db.get_user(user.id)
    if user.username:
        user_data['username'] = user.username
    else:
        user_data['username'] = user.full_name
    db.update_user(user.id, user_data)
    
    # Получаем топ
    top_users = db.get_top_users(10)
    
    if not top_users:
        await update.message.reply_text("📊 Пока нет игроков в топе")
        return
    
    # Получаем место текущего пользователя в общем рейтинге
    all_users = db.get_top_users(10000)
    user_rank = next((i+1 for i, (uid, _) in enumerate(all_users) if uid == str(user.id)), 99999)
    
    # Определяем эмодзи для мест
    medal_emojis = ["🥇", "🥈", "🥉", "🏅", "🏅", "🏅", "🏅", "🏅", "🏅", "🏅"]
    
    top_text = "🏆 <b>МИРОВОЙ ТОП ПО VSCOIN</b>\n\n"
    
    for i, (user_id, user_data_item) in enumerate(top_users, 0):
        if i < len(medal_emojis):
            medal = medal_emojis[i]
        
        # Получаем имя пользователя из БД
        username = user_data_item.get('username', '')
        
        # Если в БД нет username, пытаемся получить имя пользователя из Telegram
        if not username or username == '':
            try:
                # Пробуем получить информацию о пользователе
                chat_user = await context.bot.get_chat(int(user_id))
                username = chat_user.username or chat_user.full_name
                
                # Сохраняем в БД
                user_data_item['username'] = username
                db.update_user(int(user_id), user_data_item)
            except:
                # Если не получилось, используем ID
                username = f"ID:{user_id}"
        
        # Обрезаем слишком длинные имена
        if len(username) > 20:
            username = username[:18] + "..."
        
        # Делаем ник кликабельным (синим цветом)
        # Проверяем, есть ли у пользователя username в Telegram
        try:
            chat_user = await context.bot.get_chat(int(user_id))
            if chat_user.username:
                # Если есть username в Telegram, делаем ссылку
                display_name = f'<a href="tg://user?id={user_id}">{username}</a>'
            else:
                # Если нет username, просто имя
                display_name = username
        except:
            # Если ошибка, просто показываем имя
            display_name = username
        
        top_text += f"{medal} {i+1}.  {display_name} | {format_number(user_data_item['balance'])} Vscoin\n"
    
    # Добавляем место текущего пользователя
    if user_rank <= 10000:
        rank_emoji = "🎖" if user_rank <= 100 else "📊"
        # Для текущего пользователя всегда делаем ссылку
        user_display = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        top_text += f"\n{rank_emoji}  {user_rank}.  {user_display} | {format_number(user_data['balance'])} Vscoin - ваше место"
    else:
        user_display = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        top_text += f"\n📊 Вы еще не в рейтинге | {user_display} | {format_number(user_data['balance'])} Vscoin"
    
    top_text += f"\n\n⏰ <i>Обновлено: {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}</i>"
    
    keyboard = [[InlineKeyboardButton("🔄 Обновить топ", callback_data="refresh_top")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    try:
        await update.message.reply_text(
            top_text, 
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup,
            disable_web_page_preview=True
        )
    except Exception as e:
        print(f"Ошибка отправки топа: {e}")
        # Резервный вариант - простой текст
        simple_text = "🏆 ТОП ИГРОКОВ\n\n"
        for i, (_, user_data_item) in enumerate(top_users[:5], 1):
            username = user_data_item.get('username', 'Игрок')[:15]
            if not username or username == '':
                username = "Игрок"
            balance = format_number(user_data_item.get('balance', 0))
            simple_text += f"{i}. {username}: {balance} Vscoin\n"
        
        simple_text += f"\nВаше место: {user_rank}\nВаш баланс: {format_number(user_data.get('balance', 0))} Vscoin"
        await update.message.reply_text(simple_text, reply_markup=reply_markup)
async def refresh_top_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопки обновления топа"""
    query = update.callback_query
    user = query.from_user
    
    # Создаем новое сообщение-обновление
    fake_message = type('obj', (object,), {
        'chat_id': query.message.chat_id,
        'message_id': query.message.message_id,
        'from_user': user,
        'reply_text': update.message.reply_text if hasattr(update, 'message') else None,
        'reply_to_message': None,
        'text': '/top',
        'entities': []
    })()
    
    fake_update = Update(update.update_id, message=fake_message)
    
    # Удаляем старое сообщение
    try:
        await query.message.delete()
    except:
        pass
    
    # Вызываем команду top
    await top(fake_update, context)
    await query.answer("Топ обновлен! 🔄")
async def give_money(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Улучшенная команда перевода денег"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Если это ответ на сообщение
    if update.message.reply_to_message:
        receiver = update.message.reply_to_message.from_user
        
        if len(context.args) < 1:
            await update.message.reply_text(
                "❌ Использование: ответьте на сообщение пользователя с '/передать [сумма]'"
            )
            return
        
        amount_text = context.args[0].lower()
        
        if amount_text == 'все' or amount_text == 'all':
            amount = user_data['balance']
            if amount <= 0:
                await update.message.reply_text("❌ У вас нет денег для перевода")
                return
            
            # ПОДТВЕРЖДЕНИЕ для перевода "все"
            context.user_data[f'transfer_{user.id}'] = {
                'receiver_id': receiver.id,
                'receiver_name': receiver.full_name,
                'amount': amount,
                'is_all': True
            }
            
            # Расчет комиссии
            commission = int(amount * 0.15)  # 15% комиссия
            received_amount = amount - commission
            
            # Кнопки подтверждения
            keyboard = [
                [InlineKeyboardButton("✅ Да", callback_data=f"transfer_confirm_{user.id}"),
                 InlineKeyboardButton("❌ Нет", callback_data=f"transfer_cancel_{user.id}")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            # Синие ники
            user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
            receiver_link = f'<a href="tg://user?id={receiver.id}">{receiver.full_name}</a>'
            
            await update.message.reply_text(
                f"❓ {user_link}, ты точно хочешь передать {format_number(amount)} VsCoin игроку {receiver_link}?\n"
                f"💸 Комиссия: {format_number(commission)} VsCoin\n"
                f"📥 Получит: {format_number(received_amount)} VsCoin",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
            return
        
        else:
            # Обычный перевод
            try:
                amount = parse_bet(amount_text, user_data['balance'])
            except:
                await update.message.reply_text("❌ Неверный формат суммы")
                return
    else:
        # Перевод через упоминание
        if len(context.args) < 2:
            await update.message.reply_text(
                "❌ Использование:\n"
                "1. Ответьте на сообщение с '/передать [сумма]'\n"
                "2. '/передать [сумма] @username'"
            )
            return
        
        try:
            amount = parse_bet(context.args[0], user_data['balance'])
            receiver_username = context.args[1].replace('@', '')
        except:
            await update.message.reply_text("❌ Неверный формат суммы")
            return
        
        # Поиск получателя
        receiver_id = None
        receiver_name = ""
        
        # Сначала ищем по username
        for uid, data in db.data.items():
            if data.get('username', '').lower() == receiver_username.lower():
                receiver_id = int(uid)
                receiver_name = data.get('username', receiver_username)
                break
        
        # Если не нашли, пробуем как ID
        if not receiver_id and receiver_username.isdigit():
            receiver_id = int(receiver_username)
            if str(receiver_id) in db.data:
                receiver_name = db.data[str(receiver_id)].get('username', 'Игрок')
        
        if not receiver_id:
            await update.message.reply_text("❌ Пользователь не найден")
            return
        
        receiver = await context.bot.get_chat(receiver_id)
    
    # Проверки для обычного перевода
    if amount <= 0:
        await update.message.reply_text("❌ Сумма должна быть больше 0")
        return
    
    if user_data['balance'] < amount:
        await update.message.reply_text(f"❌ Недостаточно средств. Доступно: {format_number(user_data['balance'])} VsCoin")
        return
    
    if user.id == receiver.id:
        await update.message.reply_text("❌ Нельзя переводить деньги самому себе")
        return
    
    # Расчет комиссии (15%)
    commission = int(amount * 0.15)
    received_amount = amount - commission
    
    # Для суммы "все" уже показали подтверждение, для обычной суммы делаем сразу
    if amount_text != 'все' and amount_text != 'all':
        # Выполняем перевод сразу
        user_data['balance'] -= amount
        receiver_data = db.get_user(receiver.id)
        receiver_data['balance'] += received_amount
        
        db.update_user(user.id, user_data)
        db.update_user(receiver.id, receiver_data)
        
        # Форматируем сообщение
        user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        receiver_link = f'<a href="tg://user?id={receiver.id}">{receiver.full_name}</a>'
        
        await update.message.reply_text(
            f"➡️ {user_link} передал(-а) {format_number(amount)} VsCoin игроку {receiver_link}.\n"
            f"💸 Комиссия: {format_number(commission)} VsCoin\n"
            f"·····················\n"
            f"💰 Баланс: {format_number(user_data['balance'])} VsCoin",
            parse_mode=ParseMode.HTML
        )
        
        # Уведомляем получателя
        try:
            await context.bot.send_message(
                chat_id=receiver.id,
                text=f"💸 Вам перевели {format_number(received_amount)} VsCoin от {user.full_name}\n"
                     f"💰 Ваш баланс: {format_number(receiver_data['balance'])} VsCoin"
            )
        except:
            pass

async def give_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок подтверждения перевода"""
    query = update.callback_query
    user = query.from_user
    data = query.data
    
    # Извлекаем user_id и действие
    parts = data.split('_')
    action = parts[1]
    transfer_user_id = int(parts[2])
    
    # Проверяем, что это тот же пользователь
    if user.id != transfer_user_id:
        await query.answer("❌ Это не ваше подтверждение")
        return
    
    transfer_key = f'transfer_{user.id}'
    
    if action == "cancel":
        # Отмена перевода
        if transfer_key in context.user_data:
            del context.user_data[transfer_key]
        
        await query.edit_message_text("❌ Перевод отменен")
        await query.answer()
        return
    
    elif action == "confirm":
        # Подтверждение перевода
        if transfer_key not in context.user_data:
            await query.edit_message_text("❌ Данные перевода устарели")
            await query.answer()
            return
        
        transfer_data = context.user_data[transfer_key]
        receiver_id = transfer_data['receiver_id']
        receiver_name = transfer_data['receiver_name']
        amount = transfer_data['amount']
        
        user_data = db.get_user(user.id)
        
        # Проверяем баланс еще раз
        if user_data['balance'] < amount:
            await query.edit_message_text("❌ Недостаточно средств")
            del context.user_data[transfer_key]
            await query.answer()
            return
        
        # Расчет комиссии
        commission = int(amount * 0.15)
        received_amount = amount - commission
        
        # Выполняем перевод
        user_data['balance'] -= amount
        receiver_data = db.get_user(receiver_id)
        receiver_data['balance'] += received_amount
        
        db.update_user(user.id, user_data)
        db.update_user(receiver_id, receiver_data)
        
        # Удаляем данные перевода
        del context.user_data[transfer_key]
        
        # Форматируем сообщение
        user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        receiver_link = f'<a href="tg://user?id={receiver_id}">{receiver_name}</a>'
        
        await query.edit_message_text(
            f"➡️ {user_link} передал(-а) {format_number(amount)} VsCoin игроку {receiver_link}.\n"
            f"💸 Комиссия: {format_number(commission)} VsCoin\n"
            f"·····················\n"
            f"💰 Баланс: {format_number(user_data['balance'])} VsCoin",
            parse_mode=ParseMode.HTML
        )
        
        # Уведомляем получателя
        try:
            receiver_user = await context.bot.get_chat(receiver_id)
            await context.bot.send_message(
                chat_id=receiver_id,
                text=f"💸 Вам перевели {format_number(received_amount)} VsCoin от {user.full_name}\n"
                     f"💰 Ваш баланс: {format_number(receiver_data['balance'])} VsCoin"
            )
        except:
            pass
        
        await query.answer("✅ Перевод выполнен")


async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    total_users = 0
    active_users = 0
    total_balance = 0
    total_won = 0
    total_lost = 0
    total_bitcoin = 0
    users_with_business = 0
    total_business_balance = 0
    
    for user_id, data in db.data.items():
        if data.get('is_admin', False):
            continue
            
        total_users += 1
        
        if data.get('games_played', 0) > 0:
            active_users += 1
            
        total_balance += data.get('balance', 0)
        total_won += data.get('won_amount', 0)
        total_lost += data.get('lost_amount', 0)
        total_bitcoin += data.get('bitcoin_balance', 0)
        
        if data.get('business'):
            users_with_business += 1
            total_business_balance += data.get('business_balance', 0)
    
    stats_text = (
        "📊 <b>Статистика бота</b>\n\n"
        f"👥 <b>Всего пользователей:</b> {total_users}\n"
        f"🎮 <b>Активных пользователей:</b> {active_users}\n"
        f"💰 <b>Общий баланс Vscoin:</b> {format_number(total_balance)}\n"
        f"🪙 <b>Общий баланс Bitcoin:</b> {total_bitcoin}\n"
        f"🏆 <b>Всего выиграно:</b> {format_number(total_won)}\n"
        f"📉 <b>Всего проиграно:</b> {format_number(total_lost)}\n"
        f"🏢 <b>Пользователей с бизнесом:</b> {users_with_business}\n"
        f"💼 <b>Баланс бизнесов:</b> {format_number(total_business_balance)}\n"
        f"📈 <b>Общий оборот:</b> {format_number(total_won + total_lost)}\n\n"
        f"<i>Статистика собрана на {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}</i>"
    )
    
    await update.message.reply_text(stats_text, parse_mode=ParseMode.HTML)

async def promo_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if len(context.args) < 1:
        await update.message.reply_text("Использование: 'промо [код]'")
        return
    
    code = context.args[0].upper()
    amount = db.use_promocode(code, user.id)
    
    if amount > 0:
        user_data['balance'] += amount
        db.update_user(user.id, user_data)
        
        await update.message.reply_text(
            f"🎉 Промокод активирован!\n"
            f"💰 Вы получили: {format_number(amount)} Vscoin\n"
            f"💰 Теперь ваш баланс: {format_number(user_data['balance'])} Vscoin"
        )
    else:
        await update.message.reply_text("❌ Неверный или уже использованный промокод")

async def earn_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not db.advertisements:
        await update.message.reply_text("На данный момент нет доступных заданий для заработка биткоинов.")
        return
    
    tasks_text = "<b>🪙 Здесь вы можете заработать биткоин</b>\n\n"
    tasks_text += "ℹ️Ниже задания которыми вы можете заработать биткоин🪙 и обменять его на Vscoin\n\n"
    
    keyboard = []
    for task_id, task in db.advertisements.items():
        if task_id in user_data.get('completed_advertisements', []):
            tasks_text += f"✅ {task['channel']} - {task['bitcoin_reward']} биткоинов (выполнено)\n"
        else:
            tasks_text += f"🔘 {task['channel']} - {task['bitcoin_reward']} биткоинов\n"
            keyboard.append([InlineKeyboardButton(f"Подписаться на {task['channel']}", callback_data=f"earn_{task_id}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard) if keyboard else None
    
    await update.message.reply_text(tasks_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def earn_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    task_id = query.data.split('_')[1]
    
    if task_id not in db.advertisements:
        await query.answer("Задание больше не доступно")
        return
    
    if task_id in user_data.get('completed_advertisements', []):
        await query.answer("Вы уже выполнили это задание")
        return
    
    task = db.advertisements[task_id]
    
    keyboard = [[InlineKeyboardButton("✅ Проверить подписку", callback_data=f"check_sub_{task_id}")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"Задание: Подписаться на {task['channel']}\n\n"
        f"Награда: {task['bitcoin_reward']} биткоинов\n\n"
        f"После подписки нажмите кнопку 'Проверить подписку'",
        reply_markup=reply_markup
    )

async def check_sub_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    task_id = query.data.split('_')[2]
    
    if task_id not in db.advertisements:
        await query.answer("Задание больше не доступно")
        return
    
    if task_id in user_data.get('completed_advertisements', []):
        await query.answer("Вы уже выполнили это задание")
        return
    
    task = db.advertisements[task_id]
    reward = task['bitcoin_reward']
    
    user_data['bitcoin_balance'] = user_data.get('bitcoin_balance', 0) + reward
    
    if 'completed_advertisements' not in user_data:
        user_data['completed_advertisements'] = []
    user_data['completed_advertisements'].append(task_id)
    
    db.update_user(user.id, user_data)
    
    await query.edit_message_text(
        f"✅ Вы успешно выполнили задание!\n"
        f"Вам начислено: {reward} биткоинов🪙\n\n"
        f"Теперь вы можете обменять их в P2P обменнике на Vscoin."
    )

async def exchange_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [[InlineKeyboardButton("💸 Продать", callback_data="exchange_sell")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "P2P ОБМЕННИК\n\n"
        "ℹ️ Здесь вы можете обменять биткоин 🪙 на Vscoin 💸",
        reply_markup=reply_markup
    )

async def exchange_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if query.data == "exchange_sell":
        bitcoin_balance = user_data.get('bitcoin_balance', 0)
        bitcoin_rate = db.settings.get('bitcoin_rate', 500)
        bitcoin_percentage = db.settings.get('bitcoin_rate_percentage', 0)
        
        keyboard = []
        if bitcoin_balance >= 1:
            keyboard.append([InlineKeyboardButton("1 Биткоин", callback_data="exchange_sell_1")])
        
        if bitcoin_balance > 1:
            keyboard.append([InlineKeyboardButton("Максимум", callback_data="exchange_sell_max")])
        
        keyboard.append([InlineKeyboardButton("Назад", callback_data="exchange_back")])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "💸Продать биткоин💸\n\n"
            f"ℹ️ Здесь вы можете продать биткоин боту\n"
            f"Оф.Курс: 1 Биткоин🪙 = {bitcoin_rate} Vscoin💸 • {bitcoin_percentage}%\n\n"
            f"Ваш баланс: {bitcoin_balance} биткоинов",
            reply_markup=reply_markup
        )
    
    elif query.data == "exchange_sell_1":
        await process_exchange(query, user_data, 1)
    
    elif query.data == "exchange_sell_max":
        bitcoin_balance = user_data.get('bitcoin_balance', 0)
        await process_exchange(query, user_data, bitcoin_balance)
    
    elif query.data == "exchange_back":
        keyboard = [[InlineKeyboardButton("💸 Продать", callback_data="exchange_sell")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "P2P ОБМЕННИК\n\n"
            "ℹ️ Здесь вы можете обменять биткоин 🪙 на Vscoin 💸",
            reply_markup=reply_markup
        )
    
    elif query.data.startswith("exchange_confirm_"):
        amount = int(query.data.split('_')[2])
        await confirm_exchange(query, user_data, amount)
    
    elif query.data.startswith("exchange_cancel_"):
        await cancel_exchange(query)
    
    await query.answer()

async def process_exchange(query, user_data, amount):
    bitcoin_rate = db.settings.get('bitcoin_rate', 500)
    total_vscoin = amount * bitcoin_rate
    
    keyboard = [[
        InlineKeyboardButton("✅ Да", callback_data=f"exchange_confirm_{amount}"),
        InlineKeyboardButton("❌ Отменить", callback_data=f"exchange_cancel_{amount}")
    ]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"💸 Подтверждение продажи\n\n"
        f"Вы хотите продать {amount} биткоинов🪙\n"
        f"За {total_vscoin} Vscoin💸\n\n"
        f"Подтвердите действие:",
        reply_markup=reply_markup
    )

async def confirm_exchange(query, user_data, amount):
    user = query.from_user
    bitcoin_rate = db.settings.get('bitcoin_rate', 500)
    total_vscoin = amount * bitcoin_rate
    
    if user_data.get('bitcoin_balance', 0) < amount:
        await query.edit_message_text("❌ Недостаточно биткоинов для обмена")
        return
    
    user_data['bitcoin_balance'] -= amount
    user_data['balance'] += total_vscoin
    
    db.update_user(user.id, user_data)
    
    await query.edit_message_text(
        f"✅ Обмен успешно завершен!\n\n"
        f"Вы продали {amount} биткоинов🪙\n"
        f"Получено: {total_vscoin} Vscoin💸\n\n"
        f"Новый баланс: {user_data['balance']} Vscoin💸"
    )

async def cancel_exchange(query):
    keyboard = [[InlineKeyboardButton("💸 Продать", callback_data="exchange_sell")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "P2P ОБМЕННИК\n\n"
        "ℹ️ Здесь вы можете обменять биткоин 🪙 на Vscoin 💸",
        reply_markup=reply_markup
    )

async def kurs_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /kurs [новый курс]")
        return
    
    try:
        new_rate = int(context.args[0])
        if new_rate <= 0:
            await update.message.reply_text("Курс должен быть положительным числом")
            return
        
        old_rate = db.settings.get('bitcoin_rate', 500)
        percentage_change = ((new_rate - old_rate) / old_rate) * 100
        
        db.settings['bitcoin_rate'] = new_rate
        db.settings['bitcoin_rate_percentage'] = percentage_change
        db.save()
        
        await update.message.reply_text(
            f"✅ Курс биткоина обновлен!\n"
            f"Новый курс: 1 Биткоин🪙 = {new_rate} Vscoin💸 • {percentage_change:.1f}%"
        )
    except ValueError:
        await update.message.reply_text("Курс должен быть числом")

async def advertisement_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if len(context.args) < 2:
        await update.message.reply_text("Использование: /advertisement [канал] [количество биткоинов]")
        return
    
    channel = context.args[0]
    
    try:
        bitcoin_reward = int(context.args[1])
        if bitcoin_reward <= 0:
            await update.message.reply_text("Количество биткоинов должно быть положительным числом")
            return
    except ValueError:
        await update.message.reply_text("Количество биткоинов должно быть числом")
        return
    
    task_id = str(int(time.time()))
    
    db.advertisements[task_id] = {
        'channel': channel,
        'bitcoin_reward': bitcoin_reward
    }
    db.save()
    
    await update.message.reply_text(
        f"✅ Рекламное задание создано!\n\n"
        f"Канал: {channel}\n"
        f"Награда: {bitcoin_reward} биткоинов🪙"
    )

async def remove_ad_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if not db.advertisements:
        await update.message.reply_text("❌ Нет активных рекламных заданий")
        return
    
    text = "📋 Список рекламных заданий:\n\n"
    keyboard = []
    
    for task_id, task in db.advertisements.items():
        text += f"ID: {task_id} - {task['channel']} - {task['bitcoin_reward']} биткоинов\n"
        keyboard.append([InlineKeyboardButton(f"Удалить {task['channel']}", callback_data=f"removead_{task_id}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(text, reply_markup=reply_markup)

async def remove_ad_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await query.answer("❌ У вас нет прав для выполнения этой команды")
        return
    
    task_id = query.data.split('_')[1]
    
    if task_id in db.advertisements:
        del db.advertisements[task_id]
        db.save()
        await query.edit_message_text(f"✅ Рекламное задание {task_id} удалено!")
    else:
        await query.answer("❌ Задание не найдено")
# ЗДЕСЬ ЗАКАНЧИВАЕТСЯ ФУНКЦИЯ remove_ad_callback

# А ЭТА ФУНКЦИЯ ДОЛЖНА БЫТЬ ОТДЕЛЬНО, НЕ ВНУТРИ remove_ad_callback!
async def business_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('business'):
        await update.message.reply_text("У вас уже есть бизнес.")
        return
    
    business_list = "Доступные бизнесы:\n\n"
    for biz_type, business in BUSINESSES.items():
        business_list += f"{business['emoji']} {business['name']} - {format_number(business['price'])} Vscoin\n"
    
    business_list += "\nЧтобы купить бизнес, используйте команду: /buy_business [название]"
    await update.message.reply_text(business_list)

async def buy_business_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('business'):
        await update.message.reply_text("У вас уже есть бизнес.")
        return
    
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /buy_business [название]")
        return
    
    business_name = " ".join(context.args).lower()
    business_type = None
    
    for biz_type, business in BUSINESSES.items():
        if business['name'].lower() == business_name:
            business_type = biz_type
            break
    
    if not business_type:
        await update.message.reply_text("Бизнес не найден.")
        return
    
    business = BUSINESSES[business_type]
    
    if user_data['balance'] < business['price']:
        await update.message.reply_text("Недостаточно средств.")
        return
    
    user_data['balance'] -= business['price']
    user_data['business'] = business_type
    user_data['business_balance'] = 0
    user_data['business_last_updated'] = datetime.datetime.now().isoformat()
    
    db.update_user(user.id, user_data)
    
    await update.message.reply_text(
        f"✅ Вы купили бизнес {business['name']}!\n"
        f"Списано: {format_number(business['price'])} Vscoin\n"
        f"Новый баланс: {format_number(user_data['balance'])} Vscoin"
    )
async def business_management_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('business'):
        await update.message.reply_text("❌ У вас нет бизнеса. Купите бизнес через команду 'бизнес'")
        return
    
    business_type = user_data['business']
    business = BUSINESSES.get(business_type, {})
    
    if user_data.get('business_last_updated'):
        last_updated = datetime.datetime.fromisoformat(user_data['business_last_updated'])
        time_diff = datetime.datetime.now() - last_updated
        hours_passed = time_diff.total_seconds() / 3600
        
        profit = int(hours_passed * business['hourly_profit'])
        user_data['business_balance'] += profit
        user_data['business_last_updated'] = datetime.datetime.now().isoformat()
        db.update_user(user.id, user_data)
    
    keyboard = [
        [InlineKeyboardButton("💵 Снять деньги", callback_data="biz_withdraw")],
        [InlineKeyboardButton("💰 Продать бизнес", callback_data="biz_sell")],
        [InlineKeyboardButton("❌ Закрыть", callback_data="biz_close")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🏢 <b>Управление бизнесом</b>\n\n"
        f"ℹ️ Вы попали в меню бизнеса здесь вы можете снять ваш доход бизнеса, или продать его за половину его стоимости\n\n"
        f"📊 <b>Бизнес:</b> {business['emoji']} {business['name']}\n"
        f"💰 <b>Баланс бизнеса:</b> {format_number(user_data['business_balance'])} Vscoin\n"
        f"📈 <b>Прибыль в час:</b> {format_number(business['hourly_profit'])} Vscoin\n"
        f"📅 <b>Прибыль в день:</b> {format_number(business['daily_profit'])} Vscoin\n\n"
        f"Выберите действие:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def biz_management_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('business'):
        await query.answer("❌ У вас нет бизнеса")
        return
    
    business_type = user_data['business']
    business = BUSINESSES.get(business_type, {})
    
    if query.data == "biz_close":
        await query.message.delete()
        await query.answer()
        return
    
    if query.data == "biz_withdraw":
        if user_data['business_balance'] <= 0:
            await query.answer("❌ На балансе бизнеса нет денег")
            return
        
        context.user_data['awaiting_business_withdraw'] = True
        context.user_data['withdraw_user_id'] = user.id
        
        await query.edit_message_text(
            f"💵 <b>Снятие денег с бизнеса</b>\n\n"
            f"💰 <b>Доступно:</b> {format_number(user_data['business_balance'])} Vscoin\n\n"
            f"Введите сумму для снятия (или 'все'):",
            parse_mode=ParseMode.HTML
        )
        await query.answer()
        return
    
    if query.data == "biz_sell":
        sell_price = business['price'] // 2
        total_amount = sell_price + user_data['business_balance']
        
        keyboard = [
            [InlineKeyboardButton("✅ Да, продать", callback_data="biz_sell_confirm")],
            [InlineKeyboardButton("❌ Нет, отмена", callback_data="biz_back")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            f"💰 <b>Продажа бизнеса</b>\n\n"
            f"📊 <b>Бизнес:</b> {business['emoji']} {business['name']}\n"
            f"💵 <b>Стоимость продажи:</b> {format_number(sell_price)} Vscoin (50% от стоимости)\n"
            f"💰 <b>Баланс бизнеса:</b> {format_number(user_data['business_balance'])} Vscoin\n"
            f"🏦 <b>Итого получите:</b> {format_number(total_amount)} Vscoin\n\n"
            f"Вы уверены, что хотите продать бизнес?",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        await query.answer()
        return
    
    if query.data == "biz_sell_confirm":
        sell_price = business['price'] // 2
        total_amount = sell_price + user_data['business_balance']
        
        user_data['balance'] += total_amount
        user_data['business'] = None
        user_data['business_balance'] = 0
        user_data['business_last_updated'] = None
        
        db.update_user(user.id, user_data)
        
        await query.edit_message_text(
            f"✅ <b>Бизнес продан</b>\n\n"
            f"📊 <b>Продан бизнес:</b> {business['emoji']} {business['name']}\n"
            f"💵 <b>Получено:</b> {format_number(total_amount)} Vscoin\n"
            f"🏦 <b>Ваш баланс:</b> {format_number(user_data['balance'])} Vscoin\n\n"
            f"Вы можете купить новый бизнес через команду 'бизнес'",
            parse_mode=ParseMode.HTML
        )
        await query.answer()
        return
    
    if query.data == "biz_back":
        fake_update = Update(update.update_id, message=query.message)
        await business_management_command(fake_update, context)
        await query.answer()
        return
    
    await query.answer()

async def handle_business_withdraw(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if not context.user_data.get('awaiting_business_withdraw', False) or context.user_data.get('withdraw_user_id') != user.id:
        return
    
    user_data = db.get_user(user.id)
    
    if not user_data.get('business'):
        await update.message.reply_text("❌ У вас нет бизнеса")
        context.user_data['awaiting_business_withdraw'] = False
        return
    
    text = update.message.text.lower()
    
    if text == 'все' or text == 'all':
        amount = user_data['business_balance']
    else:
        try:
            amount = parse_bet(text)
        except:
            await update.message.reply_text("Неверный формат суммы")
            return
    
    if amount <= 0:
        await update.message.reply_text("Сумма должна быть положительной")
        return
    
    if amount > user_data['business_balance']:
        await update.message.reply_text("❌ Недостаточно средств на балансе бизнеса")
        return
    
    user_data['business_balance'] -= amount
    user_data['balance'] += amount
    db.update_user(user.id, user_data)
    
    await update.message.reply_text(
        f"✅ <b>Успешное снятие</b>\n\n"
        f"💵 <b>Снято:</b> {format_number(amount)} Vscoin\n"
        f"💰 <b>Баланс бизнеса:</b> {format_number(user_data['business_balance'])} Vscoin\n"
        f"🏦 <b>Ваш баланс:</b> {format_number(user_data['balance'])} Vscoin",
        parse_mode=ParseMode.HTML
    )
    
    context.user_data['awaiting_business_withdraw'] = False

# Банковская система
async def bank_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("💳 Депозит", callback_data="bank_deposit")],
        [InlineKeyboardButton("💲 Взять кредит", callback_data="bank_credit")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🏦 <b>Банковская система</b>\n\n"
        "ℹ️ Здесь вы можете положить деньги под процент или взять кредит на некоторый срок.",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def credit_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    active_credit = None
    for credit in user_data.get('credits', []):
        if credit.get('status') == 'approved':
            active_credit = credit
            break
    
    if not active_credit:
        await update.message.reply_text("❌ У вас нет активных кредитов")
        return
    
    amount_to_return = int(active_credit['amount'] * (1 + CREDIT_INTEREST/100))
    
    if user_data['balance'] < amount_to_return:
        await update.message.reply_text("❌ Недостаточно средств для погашения кредита")
        return
    
    user_data['balance'] -= amount_to_return
    active_credit['status'] = 'paid'
    
    db.update_user(user.id, user_data)
    await update.message.reply_text(
        f"✅ Кредит успешно погашен!\n"
        f"💸 Сумма погашения: {format_number(amount_to_return)} Vscoin\n"
        f"💰 Ваш баланс: {format_number(user_data['balance'])} Vscoin"
    )

async def bank_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    data = query.data
    
    if data == "bank_deposit":
        await deposit_menu(query)
    elif data == "bank_credit":
        await credit_menu(query)
    elif data == "bank_back":
        keyboard = [
            [InlineKeyboardButton("💳 Депозит", callback_data="bank_deposit")],
            [InlineKeyboardButton("💲 Взять кредит", callback_data="bank_credit")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "🏦 <b>Банковская система</b>\n\n"
            "ℹ️ Здесь вы можете положить деньги под процент или взять кредит на некоторый срок.",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
    
    await query.answer()

async def deposit_menu(query):
    user = query.from_user
    user_data = db.get_user(user.id)
    
    has_deposits = len(user_data.get('deposits', [])) > 0
    
    keyboard = []
    if has_deposits:
        keyboard.append([InlineKeyboardButton("💵 Снять с депозита", callback_data="deposit_withdraw_menu")])
    keyboard.append([InlineKeyboardButton("💸 Создать депозит", callback_data="deposit_create")])
    keyboard.append([InlineKeyboardButton("❌ Отменить", callback_data="bank_back")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    text = "<b>💳 Меню депозитов</b>\n\n"
    if has_deposits:
        text += "<b>Ваши активные депозиты:</b>\n"
        for i, deposit in enumerate(user_data['deposits']):
            type_name = "Открытый" if deposit['type'] == 'open' else "Закрытый"
            text += f"{i+1}. {format_number(deposit['amount'])} Vscoin - {deposit['term']} дней ({type_name})\n"
    else:
        text += "У вас пока нет депозитов.\n"
    
    text += "\nВыберите действие:"
    
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def deposit_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    data = query.data
    
    try:
        if data == "bank_deposit":
            await deposit_menu(query)
        
        elif data == "deposit_create":
            context.user_data['awaiting_deposit_amount'] = True
            context.user_data['deposit_user_id'] = user.id
            await query.edit_message_text(
                "💸 <b>Напишите сумму которую хотите положить под проценты</b>",
                parse_mode=ParseMode.HTML
            )
        
        elif data.startswith("deposit_term_"):
            term_type = data.split('_')[2]
            
            if 'deposit_amount' not in context.user_data:
                await query.answer("❌ Сначала укажите сумму депозита")
                return
                
            context.user_data['deposit_term'] = term_type
            
            keyboard = [
                [InlineKeyboardButton("🔓 Открытый (можно снять в любой момент)", callback_data=f"deposit_type_{term_type}_open")],
                [InlineKeyboardButton("🔒 Закрытый (больший процент, снять только после срока)", callback_data=f"deposit_type_{term_type}_closed")],
                [InlineKeyboardButton("❌ Отменить", callback_data="bank_back")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                f"💸 <b>Выберите тип депозита для {term_type.replace('_', ' ')}:</b>\n\n"
                f"🔓 <b>Открытый</b> - можно снять в любой момент, но меньший процент\n"
                f"🔒 <b>Закрытый</b> - больший процент, но снять только после срока",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        
        elif data.startswith("deposit_type_"):
            parts = data.split('_')
            if len(parts) < 4:
                await query.answer("❌ Ошибка в данных депозита")
                return
                
            term_type = parts[2]
            deposit_type = parts[3]
            
            user_id = context.user_data.get('deposit_user_id')
            amount = context.user_data.get('deposit_amount')
            
            if not user_id or not amount:
                await query.edit_message_text("❌ Ошибка: данные не найдены. Начните заново.")
                return
            
            term_info = DEPOSIT_RATES.get(term_type)
            if not term_info:
                await query.edit_message_text("❌ Ошибка: неверный тип депозита")
                return
            
            user_data = db.get_user(user_id)
            
            if user_data['balance'] < amount:
                await query.edit_message_text("❌ Недостаточно средств на балансе")
                return
            
            deposit = {
                'amount': amount,
                'type': 'open' if deposit_type == 'open' else 'closed',
                'term': term_info['term'],
                'interest': term_info['interest'],
                'created_date': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                'term_type': term_type
            }
            
            if deposit_type == 'closed':
                end_date = datetime.datetime.now() + datetime.timedelta(days=term_info['term'])
                deposit['end_date'] = end_date.strftime("%Y-%m-%d %H:%M:%S")
            
            if 'deposits' not in user_data:
                user_data['deposits'] = []
            user_data['deposits'].append(deposit)
            user_data['balance'] -= amount
            db.update_user(user_id, user_data)
            
            for key in ['awaiting_deposit_amount', 'deposit_amount', 'deposit_term', 'deposit_user_id']:
                if key in context.user_data:
                    del context.user_data[key]
            
            type_name = "Открытый" if deposit_type == 'open' else "Закрытый"
            await query.edit_message_text(
                f"✅ <b>Депозит успешно создан!</b>\n\n"
                f"💸 Сумма: {format_number(amount)} Vscoin\n"
                f"📅 Срок: {term_info['term']} дней\n"
                f"📈 Процент: {term_info['interest']}%\n"
                f"🔐 Тип: {type_name}\n\n"
                f"💰 Ваш баланс: {format_number(user_data['balance'])} Vscoin",
                parse_mode=ParseMode.HTML
            )
        
        elif data == "deposit_withdraw_menu":
            await withdraw_deposit_menu(query)
        
        elif data.startswith("withdraw_deposit_"):
            deposit_index = int(data.split('_')[2])
            user_data = db.get_user(user.id)
            
            if deposit_index >= len(user_data.get('deposits', [])):
                await query.answer("❌ Депозит не найден")
                return
            
            deposit = user_data['deposits'][deposit_index]
            
            if deposit['type'] == 'closed':
                if 'end_date' in deposit:
                    end_date = datetime.datetime.strptime(deposit['end_date'], "%Y-%m-%d %H:%M:%S")
                    if datetime.datetime.now() < end_date:
                        await query.answer("❌ Этот депозит закрытый. Дождитесь конца срока.")
                        return
            
            context.user_data['withdraw_deposit_index'] = deposit_index
            context.user_data['awaiting_withdraw_amount'] = True
            context.user_data['withdraw_user_id'] = user.id
            
            await query.edit_message_text(
                f"💸 <b>Напишите сумму для снятия с депозита</b>\n\n"
                f"Доступно: {format_number(deposit['amount'])} Vscoin\n"
                f"Тип: {'Открытый' if deposit['type'] == 'open' else 'Закрытый'}",
                parse_mode=ParseMode.HTML
            )
        
        elif data == "bank_back":
            keyboard = [
                [InlineKeyboardButton("💳 Депозит", callback_data="bank_deposit")],
                [InlineKeyboardButton("💲 Взять кредит", callback_data="bank_credit")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                "🏦 <b>Банковская система</b>\n\n"
                "ℹ️ Здесь вы можете положить деньги под процент или взять кредит на некоторый срок.",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        
        else:
            await query.answer("❌ Неизвестная команда")
            
    except Exception as e:
        print(f"Ошибка в deposit_callback: {e}")
        await query.answer("❌ Произошла ошибка. Попробуйте снова.")
    
    await query.answer()

async def withdraw_deposit_menu(query):
    user = query.from_user
    user_data = db.get_user(user.id)
    
    keyboard = []
    for i, deposit in enumerate(user_data.get('deposits', [])):
        keyboard.append([InlineKeyboardButton(
            f"{format_number(deposit['amount'])} Vscoin - {deposit['term']} дней ({'Открытый' if deposit['type'] == 'open' else 'Закрытый'})", 
            callback_data=f"withdraw_deposit_{i}"
        )])
    
    keyboard.append([InlineKeyboardButton("❌ Отменить", callback_data="bank_back")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "💵 <b>Выберите депозит для снятия средств:</b>",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def handle_deposit_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = update.message.text
    
    if context.user_data.get('awaiting_deposit_amount'):
        try:
            amount = parse_bet(text)
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            user_data = db.get_user(user.id)
            if user_data['balance'] < amount:
                await update.message.reply_text("❌ Недостаточно средств")
                return
            
            context.user_data['deposit_amount'] = amount
            context.user_data['deposit_user_id'] = user.id
            context.user_data['awaiting_deposit_amount'] = False
            
            keyboard = [
                [InlineKeyboardButton("3 Дня (2%)", callback_data="deposit_term_3_days")],
                [InlineKeyboardButton("16 Дней (15%)", callback_data="deposit_term_16_days")],
                [InlineKeyboardButton("1 Месяц (25%)", callback_data="deposit_term_30_days")],
                [InlineKeyboardButton("❌ Отменить", callback_data="bank_back")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"💸 <b>Выберите срок депозита для суммы {format_number(amount)} Vscoin:</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        except Exception as e:
            print(f"Ошибка обработки суммы депозита: {e}")
            await update.message.reply_text("❌ Неверный формат суммы")
    
    elif context.user_data.get('awaiting_withdraw_amount'):
        try:
            amount = parse_bet(text)
            deposit_index = context.user_data.get('withdraw_deposit_index')
            user_id = context.user_data.get('withdraw_user_id')
            
            if deposit_index is None or user_id != user.id:
                await update.message.reply_text("❌ Ошибка данных")
                return
            
            user_data = db.get_user(user.id)
            
            if deposit_index >= len(user_data.get('deposits', [])):
                await update.message.reply_text("❌ Депозит не найден")
                return
            
            deposit = user_data['deposits'][deposit_index]
            
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            if amount > deposit['amount']:
                await update.message.reply_text("❌ Нельзя снять больше чем на депозите")
                return
            
            if deposit['type'] == 'closed':
                if 'end_date' in deposit:
                    end_date = datetime.datetime.strptime(deposit['end_date'], "%Y-%m-%d %H:%M:%S")
                    if datetime.datetime.now() < end_date:
                        await update.message.reply_text("❌ Этот депозит закрытый. Дождитесь конца срока.")
                        return
            
            interest_amount = 0
            if deposit['type'] == 'closed' and 'end_date' in deposit:
                end_date = datetime.datetime.strptime(deposit['end_date'], "%Y-%m-%d %H:%M:%S")
                if datetime.datetime.now() >= end_date:
                    interest_amount = int(deposit['amount'] * (deposit['interest'] / 100))
            
            total_amount = amount + interest_amount
            
            deposit['amount'] -= amount
            user_data['balance'] += total_amount
            
            if deposit['amount'] <= 0:
                user_data['deposits'].pop(deposit_index)
            
            db.update_user(user.id, user_data)
            
            for key in ['awaiting_withdraw_amount', 'withdraw_deposit_index', 'withdraw_user_id']:
                if key in context.user_data:
                    del context.user_data[key]
            
            await update.message.reply_text(
                f"✅ <b>Средства успешно сняты!</b>\n\n"
                f"💸 Снято: {format_number(amount)} Vscoin\n"
                f"📈 Проценты: {format_number(interest_amount)} Vscoin\n"
                f"💰 Итого получено: {format_number(total_amount)} Vscoin\n"
                f"💳 Остаток на депозите: {format_number(deposit['amount'])} Vscoin\n"
                f"🏦 Ваш баланс: {format_number(user_data['balance'])} Vscoin",
                parse_mode=ParseMode.HTML
            )
        except Exception as e:
            print(f"Ошибка обработки снятия депозита: {e}")
            await update.message.reply_text("❌ Неверный формат суммы")

async def credit_menu(query):
    user = query.from_user
    user_data = db.get_user(user.id)
    
    active_credit = None
    for credit in user_data.get('credits', []):
        if credit.get('status') == 'approved':
            active_credit = credit
            break
    
    if active_credit:
        amount_to_return = int(active_credit['amount'] * (1 + CREDIT_INTEREST/100))
        
        await query.edit_message_text(
            f"💲 <b>У вас есть активный кредит</b>\n\n"
            f"💸 Сумма: {format_number(active_credit['amount'])} Vscoin\n"
            f"📅 Срок: {active_credit['term']} дней\n"
            f"📈 Процент: {CREDIT_INTEREST}%\n"
            f"💰 К возврату: {format_number(amount_to_return)} Vscoin\n\n"
            f"Для погашения используйте команду /credit",
            parse_mode=ParseMode.HTML
        )
        return
    
    keyboard = [
        [InlineKeyboardButton("💸 Подать заявку", callback_data="credit_apply")],
        [InlineKeyboardButton("❌ Отменить", callback_data="bank_back")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "💲 <b>Меню кредитов</b>\n\n"
        "ℹ️ Здесь вы можете взять сумму денег на какой-либо срок с процентом\n\n"
        f"📈 Процентная ставка: {CREDIT_INTEREST}%\n"
        "⏰ Срок: от 1 до 60 дней\n\n"
        "Для подачи заявки нажмите кнопку ниже:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def credit_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    data = query.data
    
    if data == "credit_apply":
        context.user_data['awaiting_credit_amount'] = True
        await query.edit_message_text(
            "💲 <b>Напишите сумму которую хотите взять в кредит</b>",
            parse_mode=ParseMode.HTML
        )
    elif data.startswith("credit_approve_"):
        parts = data.split('_')
        user_id = int(parts[2])
        amount = int(parts[3])
        term = int(parts[4])
        
        user_data = db.get_user(user_id)
        user_data['balance'] += amount
        
        for credit in user_data['credits']:
            if (credit['amount'] == amount and 
                credit['term'] == term and 
                credit['status'] == 'pending'):
                credit['status'] = 'approved'
                credit['approval_date'] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                break
        
        db.update_user(user_id, user_data)
        
        await query.edit_message_text(
            f"✅ Кредит одобрен!\n"
            f"Пользователь: {user_data['username']}\n"
            f"Сумма: {format_number(amount)} Vscoin\n"
            f"Срок: {term} дней"
        )
        
        try:
            await context.bot.send_message(
                chat_id=user_id,
                text=f"✅ <b>Вам одобрили кредит!</b>\n\n"
                     f"💸 Сумма: {format_number(amount)} Vscoin\n"
                     f"📅 Срок: {term} дней\n"
                     f"📈 Процент: {CREDIT_INTEREST}%\n\n"
                     f"💰 Ваш баланс: {format_number(user_data['balance'])} Vscoin\n\n"
                     f"ℹ️ <b>Для погашения кредита используйте команду /credit</b>\n"
                     f"⚠️ При невыплате денег аккаунт будет забанен на срок 1 месяц",
                parse_mode=ParseMode.HTML
            )
        except:
            pass
        
    elif data.startswith("credit_reject_"):
        parts = data.split('_')
        user_id = int(parts[2])
        
        user_data = db.get_user(user_id)
        
        user_data['credits'] = [credit for credit in user_data['credits'] 
                               if not (credit['status'] == 'pending')]
        
        db.update_user(user_id, user_data)
        
        await query.edit_message_text(
            f"❌ Кредит отклонен!\n"
            f"Пользователь: {user_data['username']}"
        )
        
        try:
            await context.bot.send_message(
                chat_id=user_id,
                text="❌ <b>Вам отказали в кредите</b>\n\n"
                     "Подайте заявку позже",
                parse_mode=ParseMode.HTML
            )
        except:
            pass
    
    await query.answer()

async def handle_bank_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = update.message.text
    
    if context.user_data.get('awaiting_deposit_amount'):
        try:
            amount = parse_bet(text)
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            user_data = db.get_user(user.id)
            if user_data['balance'] < amount:
                await update.message.reply_text("❌ Недостаточно средств")
                return
            
            context.user_data['deposit_amount'] = amount
            context.user_data['deposit_user_id'] = user.id
            context.user_data['awaiting_deposit_amount'] = False
            
            keyboard = [
                [InlineKeyboardButton("3 Дня (2%)", callback_data="deposit_term_3_days")],
                [InlineKeyboardButton("16 Дней (15%)", callback_data="deposit_term_16_days")],
                [InlineKeyboardButton("1 Месяц (25%)", callback_data="deposit_term_30_days")],
                [InlineKeyboardButton("❌ Отменить", callback_data="bank_back")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                "💸 <b>Выберите срок депозита:</b>",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        except:
            await update.message.reply_text("❌ Неверный формат суммы")
    
    elif context.user_data.get('awaiting_withdraw_amount'):
        try:
            amount = parse_bet(text)
            deposit_index = context.user_data['withdraw_deposit_index']
            
            user_data = db.get_user(user.id)
            deposit = user_data['deposits'][deposit_index]
            
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            if amount > deposit['amount']:
                await update.message.reply_text("❌ Нельзя снять больше чем на депозите")
                return
            
            created_date = datetime.datetime.strptime(deposit['created_date'], "%Y-%m-%d %H:%M:%S")
            days_passed = (datetime.datetime.now() - created_date).days
            
            interest_amount = 0
            if days_passed >= deposit['term']:
                interest_amount = int(deposit['amount'] * (deposit['interest'] / 100))
            
            total_amount = amount + interest_amount
            
            deposit['amount'] -= amount
            user_data['balance'] += total_amount
            
            if deposit['amount'] <= 0:
                user_data['deposits'].pop(deposit_index)
            
            db.update_user(user.id, user_data)
            
            for key in ['awaiting_withdraw_amount', 'withdraw_deposit_index']:
                if key in context.user_data:
                    del context.user_data[key]
            
            await update.message.reply_text(
                f"✅ <b>Средства успешно сняты!</b>\n\n"
                f"💸 Снято: {format_number(amount)} Vscoin\n"
                f"📈 Проценты: {format_number(interest_amount)} Vscoin\n"
                f"💰 Итого получено: {format_number(total_amount)} Vscoin\n"
                f"💳 Остаток на депозите: {format_number(deposit['amount'])} Vscoin\n"
                f"🏦 Ваш баланс: {format_number(user_data['balance'])} Vscoin",
                parse_mode=ParseMode.HTML
            )
        except:
            await update.message.reply_text("❌ Неверный формат суммы")
    
    elif context.user_data.get('awaiting_credit_amount'):
        try:
            amount = parse_bet(text)
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            context.user_data['credit_amount'] = amount
            context.user_data['awaiting_credit_amount'] = False
            context.user_data['awaiting_credit_term'] = True
            
            await update.message.reply_text(
                "📅 <b>Напишите количество дней на сколько хотите взять кредит (от 1 до 60)</b>",
                parse_mode=ParseMode.HTML
            )
        except:
            await update.message.reply_text("❌ Неверный формат суммы")
    
    elif context.user_data.get('awaiting_credit_term'):
        try:
            term = int(text)
            if term < 1 or term > 60:
                await update.message.reply_text("❌ Срок должен быть от 1 до 60 дней")
                return
            
            amount = context.user_data['credit_amount']
            user_data = db.get_user(user.id)
            
            credit = {
                'amount': amount,
                'term': term,
                'interest': CREDIT_INTEREST,
                'status': 'pending',
                'application_date': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            if 'credits' not in user_data:
                user_data['credits'] = []
            user_data['credits'].append(credit)
            db.update_user(user.id, user_data)
            
            for key in ['credit_amount', 'awaiting_credit_term']:
                if key in context.user_data:
                    del context.user_data[key]
            
            for admin_id in ADMIN_IDS:
                try:
                    keyboard = [
                        [InlineKeyboardButton("✅ Одобрить", callback_data=f"credit_approve_{user.id}_{amount}_{term}"),
                         InlineKeyboardButton("❌ Отклонить", callback_data=f"credit_reject_{user.id}")]
                    ]
                    reply_markup = InlineKeyboardMarkup(keyboard)
                    
                    await context.bot.send_message(
                        chat_id=admin_id,
                        text=f"📋 <b>Новая заявка на кредит</b>\n\n"
                             f"👤 Пользователь: {user.full_name} (@{user.username})\n"
                             f"🆔 ID: {user.id}\n"
                             f"💸 Сумма: {format_number(amount)} Vscoin\n"
                             f"📅 Срок: {term} дней\n"
                             f"📈 Процент: {CREDIT_INTEREST}%",
                        parse_mode=ParseMode.HTML,
                        reply_markup=reply_markup
                    )
                except:
                    continue
            
            await update.message.reply_text(
                "✅ <b>Ваша заявка на кредит отправлена!</b>\n\n"
                "Ожидайте решения администратора.",
                parse_mode=ParseMode.HTML
            )
        except ValueError:
            await update.message.reply_text("❌ Неверный формат срока")

# ИГРЫ
def calculate_score(cards):
    score = 0
    aces = 0
    
    for card in cards:
        rank = card[:-2]
        if rank in ['J', 'Q', 'K']:
            score += 10
        elif rank == 'A':
            aces += 1
            score += 11
        else:
            score += int(rank)
    
    while score > 21 and aces > 0:
        score -= 10
        aces -= 1
    
    return score

async def game_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда /game - показывает ВСЕ игры которые есть в боте"""
    
    game_text = """🎮 <b>ДОСТУПНЫЕ ИГРЫ</b>

💣 <code>/mines [ставка] [1-6]</code>
🛕 <code>/tower [ставка] [1-4]</code>
💰 <code>/gold [ставка]</code>
🎱 <code>/roulette [ставка] [0-36/к/ч]</code>
♣️ <code>/21 [ставка]</code>
🎲 <code>/cubes [ставка] [1-6]</code>
↕️ <code>/hilo [ставка]</code>
⚽️ <code>/football [ставка]</code>
🏀 <code>/basketball [ставка]</code>
🏺 <code>/pyramid [ставка] [1-2]</code>
🗝️ <code>/chest [ставка]</code>
⚔️ <code>/duel [ставка] [1-5]</code>
✂️ <code>/rps [ставка]</code>
💰 <code>/allin</code>

·····················
↗️ Страница 1/1"""
    
    # Кнопка с правилами (ссылка)
    keyboard = [
        [InlineKeyboardButton("📖 ПРАВИЛА ИГР", url="https://telegra.ph/Pravila-Vmines-Bot-12-23")]  # ТВОЯ ССЫЛКА
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        game_text, 
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )
# Или если кнопка должна быть callback, но не делать ничего:
async def game_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    data = query.data
    
    if data == "game_rules":
        # Просто отвечаем что кнопка нажата
        await query.answer("Открываю правила...")
        # Можно ничего не делать или открыть ссылку
        # await context.bot.openWebApp() если нужно
    
    await query.answer()
    
 # ============ КОНСТАНТЫ СИСТЕМЫ ЧЕКОВ ============

# Цена чековой книжки
CHECKBOOK_PRICE = 100000  # 100,000 VsCoin за чековую книжку

# Минимальная и максимальная сумма чека
MIN_CHECK_AMOUNT = 100  # Минимум 100 VsCoin
MAX_CHECK_AMOUNT = 1000000  # Максимум 1,000,000 VsCoin

# Максимальное количество активаций (ограничено по сумме 1,000,000)
MAX_CHECK_ACTIVATIONS = 1000000  # Максимум активаций (ограничено суммарной суммой)

# Срок действия чека (дней)
CHECK_EXPIRY_DAYS = 30  # Чеки действительны 30 дней

# ============ СИСТЕМА ЧЕКОВ ============

async def check_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда /check - система чеков"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Проверяем, есть ли чековая книжка
    if not db.has_checkbook(user.id):
        # Предлагаем купить чековую книжку
        user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        
        keyboard = [
            [InlineKeyboardButton("✅ Да", callback_data="check_buy_confirm"),
             InlineKeyboardButton("❌ Нет", callback_data="check_cancel")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await update.message.reply_text(
            f"{user_link}, Вы хотите приобрести чековую книжку\n"
            f"за {format_number(CHECKBOOK_PRICE)} VsCoin?",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # Если чековая книжка есть, показываем меню
    await show_check_menu(update.message, user, user_data)

async def show_check_menu(message, user, user_data=None):
    """Показать меню чековой книжки"""
    if user_data is None:
        user_data = db.get_user(user.id)
    
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    keyboard = [
        [InlineKeyboardButton("🧾 Создать Чек", callback_data="check_create")],
        [InlineKeyboardButton("📋 Мои Чеки", callback_data="check_my")],
        [InlineKeyboardButton("❌ Закрыть", callback_data="check_close")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    text = (
        f"🧾 <b>ЧЕКОВАЯ КНИЖКА</b>\n"
        f"·····················\n"
        f"⚡️ {user_link}, здесь ты можешь создать чек и отправить VsCoin любому пользователю без комиссии.\n\n"
        f"💰 <b>Баланс:</b> {format_number(user_data['balance'])} Vscoin\n"
        f"ℹ️ <i>Сумма чека: от {MIN_CHECK_AMOUNT} до {format_number(MAX_CHECK_AMOUNT)} VsCoin</i>"
    )
    
    if isinstance(message, Update):
        await message.message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
    else:
        await message.reply_text(text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def check_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик callback чеков"""
    query = update.callback_query
    user = query.from_user
    data = query.data
    
    await query.answer()
    
    if data == "check_close" or data == "check_cancel":
        await query.message.delete()
        return
    
    elif data == "check_buy_confirm":
        success, message = db.buy_checkbook(user.id)
        
        if success:
            user_data = db.get_user(user.id)
            await query.edit_message_text(
                f"✅ <b>Вы успешно купили чековую книжку!</b>\n"
                f"·····················\n"
                f"💰 <b>Баланс:</b> {format_number(user_data['balance'])} Vscoin\n\n"
                f"Теперь вы можете создавать чеки через меню.",
                parse_mode=ParseMode.HTML
            )
        else:
            await query.edit_message_text(f"❌ {message}")
        
        return
    
    elif data == "check_create":
        user_data = db.get_user(user.id)
        
        # Очищаем предыдущие данные
        context.user_data[f'check_create_{user.id}'] = {
            'step': 'amount',
            'amount': None,
            'activations': None,
            'password': None,
            'description': None
        }
        
        max_amount = min(MAX_CHECK_AMOUNT, user_data['balance'])
        
        # Создаем кнопки с суммами
        amounts = []
        
        # Добавляем стандартные суммы
        if max_amount >= 100:
            amounts.append(100)
        if max_amount >= 500:
            amounts.append(500)
        if max_amount >= 1000:
            amounts.append(1000)
        if max_amount >= 5000:
            amounts.append(5000)
        if max_amount >= 10000:
            amounts.append(10000)
        if max_amount >= 50000:
            amounts.append(50000)
        
        # Добавляем максимальную сумму, если она больше 0
        if max_amount > 0:
            amounts.append(max_amount)
        
        keyboard_rows = []
        
        # Группируем кнопки по 2 в ряд
        for i in range(0, len(amounts), 2):
            row = []
            if i < len(amounts):
                amount1 = amounts[i]
                row.append(InlineKeyboardButton(
                    f"{format_number(amount1)}", 
                    callback_data=f"check_amount_{amount1}"
                ))
            if i + 1 < len(amounts):
                amount2 = amounts[i + 1]
                row.append(InlineKeyboardButton(
                    f"{format_number(amount2)}", 
                    callback_data=f"check_amount_{amount2}"
                ))
            if row:
                keyboard_rows.append(row)
        
        keyboard_rows.append([InlineKeyboardButton("📝 Ввести свою сумму", callback_data="check_custom_amount")])
        keyboard_rows.append([InlineKeyboardButton("🔙 Назад", callback_data="check_back")])
        
        reply_markup = InlineKeyboardMarkup(keyboard_rows)
        
        await query.edit_message_text(
            f"💸 <b>ВЫБЕРИ СУММУ ЧЕКА</b>\n"
            f"·····················\n"
            f"💰 <b>Баланс:</b> {format_number(user_data['balance'])} Vscoin\n"
            f"📊 <b>Максимум:</b> {format_number(max_amount)} Vscoin\n\n"
            f"ℹ️ Выберите сумму из предложенных или введите свою.\n"
            f"<code>Пример: 5000 или 5к или 5.5к</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    elif data == "check_custom_amount":
        # Устанавливаем флаг для ввода текста
        context.user_data[f'check_input_{user.id}'] = 'amount'
        
        await query.edit_message_text(
            f"💸 <b>ВВЕДИТЕ СУММУ ЧЕКА</b>\n"
            f"·····················\n"
            f"💰 <b>Баланс:</b> {format_number(db.get_user(user.id)['balance'])} Vscoin\n\n"
            f"ℹ️ Введите сумму от {MIN_CHECK_AMOUNT} до {format_number(MAX_CHECK_AMOUNT)} VsCoin\n\n"
            f"<b>Примеры:</b>\n"
            f"<code>5000</code> - 5,000 Vscoin\n"
            f"<code>10к</code> - 10,000 Vscoin\n"
            f"<code>1.5к</code> - 1,500 Vscoin\n"
            f"<code>100000</code> - 100,000 Vscoin\n\n"
            f"❌ <b>Отмена:</b> /cancel",
            parse_mode=ParseMode.HTML
        )
        return
    
    elif data.startswith("check_amount_"):
        try:
            amount_str = data.replace("check_amount_", "")
            amount = int(amount_str)
            await process_check_amount(query, context, user, amount)
        except ValueError:
            await query.answer("❌ Ошибка: неверный формат суммы")
        return
    
    elif data == "check_act_min":
        user_id = user.id
        if f'check_create_{user_id}' in context.user_data:
            amount = context.user_data[f'check_create_{user_id}']['amount']
            activations = 1
            await create_check_final(query, context, user, amount, activations)
        return
    
    elif data == "check_act_max":
        user_id = user.id
        if f'check_create_{user_id}' in context.user_data:
            amount = context.user_data[f'check_create_{user_id}']['amount']
            user_data = db.get_user(user.id)
            # Максимум активаций по правилу: 1,000,000 / amount (округляем вниз)
            max_activations_by_limit = 1000000 // amount
            # Максимум по балансу
            max_activations_by_balance = user_data['balance'] // amount
            # Берем минимальное из двух
            activations = min(max_activations_by_limit, max_activations_by_balance)
            if activations < 1:
                await query.answer("❌ Недостаточно средств для создания чека")
                return
            await create_check_final(query, context, user, amount, activations)
        return
    
    elif data == "check_my":
        await show_user_checks_menu(query, user)
        return
    
    elif data == "check_back":
        user_data = db.get_user(user.id)
        await show_check_menu(query.message, user, user_data)
        return
    
    elif data.startswith("check_copy_"):
        check_id = data.replace("check_copy_", "")
        check_data = db.get_check(check_id)
        if check_data:
            # ИЗМЕНЕНО: Формируем ссылку на чек с Vmines_bot
            check_link = f"https://t.me/Vmines_bot?start=check_{check_data['check_number']}"
            copy_text = (
                f"📋 <b>Ссылка на чек скопирована!</b>\n\n"
                f"🔗 Ссылка:\n"
                f"<code>{check_link}</code>\n\n"
                f"📎 Нажмите и удерживайте ссылку, чтобы скопировать\n"
                f"📤 Поделитесь этой ссылкой с друзьями"
            )
            await query.edit_message_text(
                copy_text,
                parse_mode=ParseMode.HTML
            )
        else:
            await query.answer("❌ Чек не найден")
        return
    
    elif data.startswith("check_edit_"):
        check_id = data.replace("check_edit_", "")
        await show_check_edit_menu(query, user, check_id)
        return
    
    elif data.startswith("check_setpass_"):
        check_id = data.replace("check_setpass_", "")
        context.user_data[f'check_setpass_{user.id}'] = check_id
        context.user_data[f'check_input_{user.id}'] = 'password'
        
        await query.edit_message_text(
            "🔐 <b>УСТАНОВИТЬ ПАРОЛЬ ДЛЯ ЧЕКА</b>\n"
            "·····················\n\n"
            "Введите пароль для чека:\n"
            "ℹ️ Пароль должен содержать от 4 до 20 символов\n"
            "❌ Для удаления пароля введите '0'\n\n"
            "❌ <b>Отмена:</b> /cancel",
            parse_mode=ParseMode.HTML
        )
        return
    
    elif data.startswith("check_setdesc_"):
        check_id = data.replace("check_setdesc_", "")
        context.user_data[f'check_setdesc_{user.id}'] = check_id
        context.user_data[f'check_input_{user.id}'] = 'description'
        
        await query.edit_message_text(
            "📝 <b>ДОБАВИТЬ/ИЗМЕНИТЬ ОПИСАНИЕ ЧЕКА</b>\n"
            "·····················\n\n"
            "Введите описание для чека:\n"
            "ℹ️ Описание может содержать до 100 символов\n"
            "❌ Для удаления описания введите '0'\n\n"
            "❌ <b>Отмена:</b> /cancel",
            parse_mode=ParseMode.HTML
        )
        return
    
    elif data.startswith("check_delete_"):
        check_id = data.replace("check_delete_", "")
        check_data = db.get_check(check_id)
        
        if check_data:
            # Проверяем, что пользователь является создателем чека
            if check_data['creator_id'] != user.id:
                await query.answer("❌ Вы не являетесь создателем этого чека")
                return
            
            keyboard = [
                [InlineKeyboardButton("✅ Да, удалить", callback_data=f"check_delete_confirm_{check_id}")],
                [InlineKeyboardButton("❌ Нет, отмена", callback_data=f"check_edit_{check_id}")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            remaining_activations = check_data['total_activations'] - check_data['used_activations']
            refund_amount = remaining_activations * check_data['amount']
            
            await query.edit_message_text(
                f"🗑 <b>УДАЛИТЬ ЧЕК #{check_data['check_number']}</b>\n"
                f"·····················\n"
                f"💰 Сумма за активацию: {format_number(check_data['amount'])} Vscoin\n"
                f"🔘 Активаций: {check_data['used_activations']}/{check_data['total_activations']}\n"
                f"💸 К возврату: {format_number(refund_amount)} Vscoin\n\n"
                f"⚠️ <b>Вы уверены, что хотите удалить этот чек?</b>\n"
                f"ℹ️ Неиспользованные средства будут возвращены на ваш баланс.",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        return
    
    elif data.startswith("check_delete_confirm_"):
        check_id = data.replace("check_delete_confirm_", "")
        success, message = db.delete_check(check_id, user.id)
        
        if success:
            await query.edit_message_text(f"✅ {message}")
        else:
            await query.edit_message_text(f"❌ {message}")
        return

async def show_check_edit_menu(query, user, check_id):
    """Показать меню редактирования чека"""
    check_data = db.get_check(check_id)
    
    if not check_data:
        await query.answer("❌ Чек не найден")
        return
    
    if check_data['creator_id'] != user.id:
        await query.answer("❌ Вы не являетесь создателем этого чека")
        return
    
    text = (
        f"✏️ <b>РЕДАКТИРОВАТЬ ЧЕК #{check_data['check_number']}</b>\n"
        f"·····················\n"
        f"💰 Сумма за активацию: {format_number(check_data['amount'])} Vscoin\n"
        f"🔘 Активаций: {check_data['used_activations']}/{check_data['total_activations']}\n"
    )
    
    if check_data.get('description'):
        text += f"📝 Описание: {check_data['description']}\n"
    else:
        text += f"📝 Описание: нет\n"
    
    if check_data.get('password'):
        text += f"🔐 Пароль: установлен\n"
    else:
        text += f"🔐 Пароль: нет\n"
    
    # ИЗМЕНЕНО: Ссылка с Vmines_bot
    check_link = f"https://t.me/Vmines_bot?start=check_{check_data['check_number']}"
    text += f"🔗 Ссылка: <code>{check_link}</code>\n\n"
    
    text += "Выберите действие:"
    
    keyboard = [
        [InlineKeyboardButton("📝 Изменить описание", callback_data=f"check_setdesc_{check_id}")],
        [InlineKeyboardButton("🔐 Установить/изменить пароль", callback_data=f"check_setpass_{check_id}")],
        [InlineKeyboardButton("📋 Скопировать ссылку", callback_data=f"check_copy_{check_id}")],
        [InlineKeyboardButton("🗑 Удалить чек", callback_data=f"check_delete_{check_id}")],
        [InlineKeyboardButton("🔙 Назад", callback_data="check_my")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def show_user_checks_menu(query, user):
    """Показать меню чеков пользователя"""
    user_checks = db.get_user_checks(user.id)
    
    if not user_checks:
        keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data="check_back")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "📭 <b>У вас пока нет активных чеков</b>\n"
            "Создайте первый чек через меню!",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    text = "📋 <b>ВАШИ АКТИВНЫЕ ЧЕКИ</b>\n\n"
    
    for check_id, check_data in user_checks[:10]:
        # ИЗМЕНЕНО: Правильная ссылка для редактирования с Vmines_bot
        edit_link = f"https://t.me/Vmines_bot?start=editcheck_{check_id}"
        
        text += (
            f"🧾 <b>Чек #{check_data['check_number']}</b>\n"
            f"💰 Сумма: {format_number(check_data['amount'])} Vscoin\n"
            f"🔘 Активаций: {check_data['used_activations']}/{check_data['total_activations']}\n"
        )
        
        if check_data.get('description'):
            text += f"📝 Описание: {check_data['description'][:30]}...\n"
        
        if check_data.get('password'):
            text += f"🔐 Защищен паролем\n"
        
        # Ссылка для редактирования с правильным именем бота
        text += f"✏️ [Редактировать]({edit_link})\n\n"
    
    if len(user_checks) > 10:
        text += f"📄 ... и еще {len(user_checks) - 10} чеков\n\n"
    
    keyboard = [
        [InlineKeyboardButton("🔙 Назад", callback_data="check_back")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(text, parse_mode=ParseMode.HTML, reply_markup=reply_markup, disable_web_page_preview=True)

async def process_check_amount(query, context, user, amount):
    """Обработка выбранной суммы чека"""
    user_data = db.get_user(user.id)
    
    # Проверяем сумму
    if amount < MIN_CHECK_AMOUNT:
        await query.answer(f"❌ Минимальная сумма: {MIN_CHECK_AMOUNT} Vscoin")
        return
    
    if amount > MAX_CHECK_AMOUNT:
        await query.answer(f"❌ Максимальная сумма: {format_number(MAX_CHECK_AMOUNT)} Vscoin")
        return
    
    if amount > user_data['balance']:
        await query.answer(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])} Vscoin")
        return
    
    # Сохраняем сумму в context
    if f'check_create_{user.id}' not in context.user_data:
        context.user_data[f'check_create_{user.id}'] = {}
    
    context.user_data[f'check_create_{user.id}']['amount'] = amount
    
    # Рассчитываем максимальное количество активаций
    max_activations_by_limit = 1000000 // amount
    max_activations_by_balance = user_data['balance'] // amount
    max_activations = min(max_activations_by_limit, max_activations_by_balance)
    
    if max_activations < 1:
        await query.answer("❌ Недостаточно средств для создания чека")
        return
    
    # Кнопки для выбора количества активаций
    keyboard = []
    
    # Две кнопки: минимум и максимум
    keyboard.append([
        InlineKeyboardButton(
            f"1 активация = {format_number(amount)} Vscoin", 
            callback_data="check_act_min"
        )
    ])
    
    keyboard.append([
        InlineKeyboardButton(
            f"{max_activations} активаций = {format_number(amount * max_activations)} Vscoin", 
            callback_data="check_act_max"
        )
    ])
    
    keyboard.append([InlineKeyboardButton("🔙 Назад", callback_data="check_create")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"🔘 <b>ВЫБЕРИ КОЛИЧЕСТВО АКТИВАЦИЙ</b>\n"
        f"·····················\n"
        f"💰 <b>Сумма за активацию:</b> {format_number(amount)} Vscoin\n"
        f"💳 <b>Ваш баланс:</b> {format_number(user_data['balance'])} Vscoin\n"
        f"🧮 <b>Макс. активаций:</b> {max_activations}\n"
        f"ℹ️ <i>Ограничение: максимальная общая сумма всех активаций = 1,000,000 VsCoin</i>\n\n"
        f"Выберите количество активаций:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def create_check_final(query, context, user, amount, activations):
    """Создание чека после выбора всех параметров"""
    user_data = db.get_user(user.id)
    
    # Проверяем общую сумму
    total_amount = amount * activations
    if total_amount > 1000000:
        await query.answer(f"❌ Максимальная общая сумма чека не может превышать 1,000,000 VsCoin")
        return
    
    # Проверяем баланс
    if user_data['balance'] < total_amount:
        await query.answer(f"❌ Недостаточно средств! Нужно: {format_number(total_amount)} Vscoin")
        return
    
    # Создаем чек
    check_id, message = db.create_check(user.id, amount, activations)
    
    if not check_id:
        await query.answer(f"❌ {message}")
        return
    
    # Получаем данные созданного чека
    check_data = db.get_check(check_id)
    
    # ИЗМЕНЕНО: Формируем ссылку с Vmines_bot
    check_link = f"https://t.me/Vmines_bot?start=check_{check_data['check_number']}"
    
    # Формируем сообщение
    check_text = (
        f"✅ <b>ЧЕК #{check_data['check_number']} СОЗДАН!</b>\n"
        f"·····················\n"
        f"💰 <b>Сумма за активацию:</b> {format_number(amount)} Vscoin\n"
        f"🔘 <b>Количество активаций:</b> {activations}\n"
        f"🧮 <b>Общая сумма:</b> {format_number(total_amount)} Vscoin\n"
        f"📅 <b>Создан:</b> {check_data['created_date']}\n\n"
        f"🔗 <b>Ссылка на чек:</b>\n"
        f"<code>{check_link}</code>\n\n"
        f"ℹ️ Отправьте эту ссылку друзьям.\n"
        f"Каждый может активировать чек только 1 раз."
    )
    
    # Кнопки управления чеком
    keyboard = [
        [InlineKeyboardButton("📋 Скопировать ссылку", callback_data=f"check_copy_{check_id}")],
        [InlineKeyboardButton("✏️ Редактировать чек", callback_data=f"check_edit_{check_id}")],
        [InlineKeyboardButton("🔙 В меню", callback_data="check_back")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(check_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def activate_check_start(update: Update, context: ContextTypes.DEFAULT_TYPE, user, check_id):
    """Активация чека через ссылку /start check_..."""
    
    # Проверяем существование чека по номеру
    check_data = db.get_check_by_number(check_id)
    
    if not check_data:
        # Если не нашли по номеру, пробуем найти по ID
        check_data = db.get_check(check_id)
    
    if not check_data:
        # Если чек не найден, показываем сообщение
        await update.message.reply_text(
            f"💎 <b>Чек не найден</b>\n\n"
            f"❌ Этот чек был удален, уже активирован или срок его действия истек.",
            parse_mode=ParseMode.HTML
        )
        return
    
    # Проверяем статус
    if check_data['status'] != 'active':
        await update.message.reply_text("❌ Этот чек уже был активирован или удален")
        return
    
    # Проверяем, не активировал ли уже пользователь
    if user.id in check_data['activated_by']:
        await update.message.reply_text("⚠️ Вы уже активировали этот чек")
        return
    
    # Формируем текст чека
    check_text = f"💎 <b>Чек на {format_number(check_data['amount'])} VsCoin</b>\n\n"
    
    # Добавляем описание только если оно есть
    if check_data.get('description'):
        check_text += f"💬 {check_data['description']}\n\n"
    
    # Добавляем информацию об активациях
    remaining = check_data['total_activations'] - check_data['used_activations']
    check_text += f"🔘 Осталось активаций: {remaining}/{check_data['total_activations']}\n\n"
    
    check_text += "Нажмите кнопку ниже, чтобы активировать чек"
    
    # Создаем кнопку с правильным callback_data
    keyboard = [[InlineKeyboardButton("✅ Активировать", callback_data=f"check_activate_{check_data['id']}")]]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Отправляем сообщение с кнопкой
    await update.message.reply_text(
        check_text,
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

# ============ ОБРАБОТЧИК АКТИВАЦИИ ЧЕКА ============

async def handle_check_activation(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик нажатия кнопки 'Активировать' на чеке"""
    query = update.callback_query
    user = query.from_user
    data = query.data
    
    await query.answer()
    
    if data.startswith("check_activate_"):
        check_id = data.replace("check_activate_", "")
        check_data = db.get_check(check_id)
        
        if not check_data:
            await query.edit_message_text("❌ Чек не найден или был удален")
            return
        
        # Проверяем статус
        if check_data['status'] != 'active':
            await query.edit_message_text("❌ Этот чек уже был активирован или удален")
            return
        
        # Проверяем, не активировал ли уже пользователь
        if user.id in check_data['activated_by']:
            await query.edit_message_text("⚠️ Вы уже активировали этот чек")
            return
        
        # Если есть пароль, запрашиваем его
        if check_data.get('password'):
            context.user_data[f'check_activate_password_{user.id}'] = {
                'check_id': check_data['id'],
                'message_id': query.message.message_id
            }
            
            await query.edit_message_text(
                "🔐 <b>Этот чек защищен паролем</b>\n\n"
                "Введите пароль для активации чека:\n\n"
                "❌ <b>Отмена:</b> /cancel",
                parse_mode=ParseMode.HTML
            )
            return
        
        # Активируем чек (теперь можно активировать свой собственный чек)
        success, message = db.activate_check(check_data['id'], user.id)
        
        if success:
            user_data = db.get_user(user.id)
            user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
            
            # Определяем, активировал ли пользователь свой собственный чек
            is_own_check = (user.id == check_data['creator_id'])
            
            if is_own_check:
                await query.edit_message_text(
                    f"✅ {user_link}, вы успешно активировали свой собственный чек!\n"
                    f"💰 Получено: {format_number(check_data['amount'])} VsCoin\n"
                    f"💳 Ваш баланс: {format_number(user_data['balance'])} VsCoin",
                    parse_mode=ParseMode.HTML
                )
            else:
                await query.edit_message_text(
                    f"✅ {user_link}, вы успешно активировали чек!\n"
                    f"💰 Получено: {format_number(check_data['amount'])} VsCoin\n"
                    f"💳 Ваш баланс: {format_number(user_data['balance'])} VsCoin",
                    parse_mode=ParseMode.HTML
                )
                
                # Отправляем уведомление создателю чека, если это не он сам
                try:
                    creator_id = check_data['creator_id']
                    if creator_id != user.id:
                        creator_data = db.get_user(creator_id)
                        user_name = user_data.get('username', user.full_name)
                        
                        remaining_activations = check_data['total_activations'] - check_data['used_activations']
                        notification_text = (
                            f"📨 <b>УВЕДОМЛЕНИЕ О ЧЕКЕ</b>\n"
                            f"·····················\n"
                            f"👤 <a href='tg://user?id={user.id}'>{user_name}</a> активировал ваш чек\n"
                            f"💰 Сумма: {format_number(check_data['amount'])} VsCoin\n"
                            f"🔘 Активаций осталось: {remaining_activations}/{check_data['total_activations']}"
                        )
                        
                        await context.bot.send_message(
                            chat_id=creator_id,
                            text=notification_text,
                            parse_mode=ParseMode.HTML
                        )
                except Exception as e:
                    print(f"Ошибка при отправке уведомления создателю чека: {e}")
                    
        else:
            await query.edit_message_text(f"❌ {message}")
        return

# ============ HANDLERS ============





async def mines_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Улучшенная игра в мины с правильными коэффициентами"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Проверка бана
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены и не можете играть!")
        return
    
    # Проверка аргументов
    if len(context.args) < 2:
        await update.message.reply_text(
            "💣 <b>ИГРА В МИНЫ</b>\n\n"
            "📝 <b>Формат:</b> <code>/mines [ставка] [мин 1-6]</code>\n\n"
            "🎯 <b>Примеры:</b>\n"
            "<code>/mines 100 3</code>\n"
            "<code>/mines 500 1</code>\n\n"
            "💰 <b>Множители:</b>\n"
            "1 мина: 1.05→1.10→1.15...\n"
            "2 мины: 1.05→1.15→1.26...\n"
            "3 мины: 1.10→1.26→1.45...\n"
            "4 мины: 1.15→1.39→1.68...\n"
            "5 мин: 1.21→1.53→1.96...\n"
            "6 мин: 1.28→1.70→2.30...",
            parse_mode=ParseMode.HTML
        )
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        mines_count = int(context.args[1])
    except:
        await update.message.reply_text("❌ Неверный формат! Пример: /mines 100 3")
        return
    
    # Проверки
    if mines_count < 1 or mines_count > 6:
        await update.message.reply_text("❌ Количество мин: 1-6!")
        return
    
    if bet <= 0:
        await update.message.reply_text("❌ Ставка должна быть > 0!")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text(f"❌ Недостаточно! Баланс: {format_number(user_data['balance'])} Vscoin")
        return
    
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Создаем поле 5x5
    field = [['❓' for _ in range(5)] for _ in range(5)]
    
    # Размещаем мины
    mines_positions = []
    while len(mines_positions) < mines_count:
        pos = (random.randint(0, 4), random.randint(0, 4))
        if pos not in mines_positions:
            mines_positions.append(pos)
    
    # Данные игры
    game_data = {
        'type': 'mines',
        'bet': bet,
        'mines_count': mines_count,
        'mines_positions': mines_positions,
        'opened_cells': [],
        'multipliers': MINE_MULTIPLIERS[mines_count],
        'current_step': 0,
        'current_multiplier': 1.0
    }
    
    # Сохраняем игру
    user_data['active_game'] = game_data
    db.update_user(user.id, user_data)
    
    # Создаем клавиатуру
    keyboard = []
    for i in range(5):
        row = []
        for j in range(5):
            row.append(InlineKeyboardButton(field[i][j], callback_data=f"mines_{i}_{j}"))
        keyboard.append(row)
    
    keyboard.append([
        InlineKeyboardButton("💰 Забрать", callback_data="mines_cashout"),
        InlineKeyboardButton("❌ Отмена", callback_data="mines_cancel")
    ])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Отправляем начальное сообщение
    win_amount = int(bet * game_data['current_multiplier'])
    
    message_text = (
        f"<a href='tg://user?id={user.id}'>{user.full_name}</a> Игра началась!\n"
        f"·····················\n"
        f"Ставка: {format_number(bet)} Vscoin\n"
        f"Мин: {mines_count}💣\n\n"
        f"💰 Можно забрать: {format_number(win_amount)} Vscoin"
    )
    
    await update.message.reply_text(
        message_text,
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def mines_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик игры в мины"""
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('active_game') or user_data['active_game'].get('type') != 'mines':
        await query.answer("❌ Нет активной игры")
        return
    
    game_data = user_data['active_game']
    
    # Отмена игры
    if query.data == "mines_cancel":
        user_data['balance'] += game_data['bet']
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
        return
    
    # Забрать выигрыш
    if query.data == "mines_cashout":
        if game_data['current_step'] == 0:
            await query.answer("❌ Сначала откройте хотя бы одну клетку!")
            return
            
        win_amount = int(game_data['bet'] * game_data['current_multiplier'])
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        
        # Показываем поле с результатом
        keyboard = []
        for i in range(5):
            row = []
            for j in range(5):
                if (i, j) in game_data['mines_positions']:
                    row.append(InlineKeyboardButton('💣', callback_data="mines_finished"))
                elif (i, j) in game_data['opened_cells']:
                    row.append(InlineKeyboardButton('💎', callback_data="mines_finished"))
                else:
                    row.append(InlineKeyboardButton('❓', callback_data="mines_finished"))
            keyboard.append(row)
        
        keyboard.append([InlineKeyboardButton("✅ Игра завершена", callback_data="mines_finished")])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        message_text = (
            f"<a href='tg://user?id={user.id}'>{user.full_name}</a> Победа!\n"
            f"·····················\n"
            f"Ставка: {format_number(game_data['bet'])} Vscoin\n"
            f"Мин: {game_data['mines_count']}💣\n"
            f"Открыто ячеек: {len(game_data['opened_cells'])}\n"
            f"💰 Выигрыш: {format_number(win_amount)} Vscoin"
        )
        
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        await query.edit_message_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # Открытие клетки
    if query.data.startswith("mines_"):
        parts = query.data.split('_')
        i, j = int(parts[1]), int(parts[2])
        
        # Проверка
        if (i, j) in game_data['opened_cells']:
            await query.answer("Эта клетка уже открыта!")
            return
        
        # Проверка на мину
        if (i, j) in game_data['mines_positions']:
            # ПРОИГРЫШ
            user_data['games_played'] += 1
            user_data['losses'] += 1
            user_data['lost_amount'] += game_data['bet']
            
            # Показываем поле с миной
            keyboard = []
            for x in range(5):
                row = []
                for y in range(5):
                    if (x, y) == (i, j):
                        row.append(InlineKeyboardButton('💥', callback_data="mines_finished"))
                    elif (x, y) in game_data['mines_positions']:
                        row.append(InlineKeyboardButton('💣', callback_data="mines_finished"))
                    elif (x, y) in game_data['opened_cells']:
                        row.append(InlineKeyboardButton('💎', callback_data="mines_finished"))
                    else:
                        row.append(InlineKeyboardButton('?', callback_data="mines_finished"))
                keyboard.append(row)
            
            keyboard.append([InlineKeyboardButton("💥 Игра завершена", callback_data="mines_finished")])
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            message_text = (
                f"<a href='tg://user?id={user.id}'>{user.full_name}</a> Проигрыш!\n"
                f"·····················\n"
                f"Ставка: {format_number(game_data['bet'])} Vscoin\n"
                f"Мин: {game_data['mines_count']}💣\n"
                f"Открыто ячеек: {len(game_data['opened_cells'])}\n"
                f"💸 Проигрыш: {format_number(game_data['bet'])} Vscoin"
            )
            
            user_data['active_game'] = None
            db.update_user(user.id, user_data)
            
            await query.edit_message_text(
                message_text,
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
            return
        
        # УСПЕШНОЕ ОТКРЫТИЕ
        game_data['opened_cells'].append((i, j))
        game_data['current_step'] += 1
        
        # Получаем текущий множитель
        if game_data['current_step'] <= len(game_data['multipliers']):
            game_data['current_multiplier'] = game_data['multipliers'][game_data['current_step'] - 1]
        else:
            # Если шагов больше чем в списке, продолжаем увеличивать по последнему шагу
            last_mult = game_data['multipliers'][-1]
            increase = (last_mult - game_data['multipliers'][-2]) / game_data['multipliers'][-2]
            game_data['current_multiplier'] = last_mult * (1 + increase) ** (game_data['current_step'] - len(game_data['multipliers']))
        
        # Обновляем игру
        user_data['active_game'] = game_data
        db.update_user(user.id, user_data)
        
        # Обновляем клавиатуру
        keyboard = []
        for x in range(5):
            row = []
            for y in range(5):
                if (x, y) in game_data['opened_cells']:
                    row.append(InlineKeyboardButton('💎', callback_data=f"mines_{x}_{y}"))
                else:
                    row.append(InlineKeyboardButton('❓', callback_data=f"mines_{x}_{y}"))
            keyboard.append(row)
        
        win_amount = int(game_data['bet'] * game_data['current_multiplier'])
        keyboard.append([
            InlineKeyboardButton("💰 Забрать", callback_data="mines_cashout"),
            InlineKeyboardButton("❌ Отмена", callback_data="mines_cancel")
        ])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        message_text = (
            f"<a href='tg://user?id={user.id}'>{user.full_name}</a> Игра продолжается!\n"
            f"·····················\n"
            f"Ставка: {format_number(game_data['bet'])} Vscoin\n"
            f"Мин: {game_data['mines_count']}💣\n"
            f"Открыто ячеек: {len(game_data['opened_cells'])}\n"
            f"💰 Можно забрать: {format_number(win_amount)} Vscoin"
        )
        
        await query.edit_message_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
    
    await query.answer()

async def mines_finished_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Колбэк для завершенной игры"""
    query = update.callback_query
    await query.answer("Игра завершена!")

# Обновленная функция football_game
async def football_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игра в футбол с профессиональным форматированием"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    original_msg_id = update.message.message_id

    # Проверки
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!", reply_to_message_id=original_msg_id)
        return
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /футбол [ставка] (гол/мимо)", reply_to_message_id=original_msg_id)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        if bet <= 0 or user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Ошибка ставки! Доступно: {format_number(user_data['balance'])}", reply_to_message_id=original_msg_id)
            return
    except:
        await update.message.reply_text("❌ Используйте: /футбол 100", reply_to_message_id=original_msg_id)
        return

    # Обработка прямого выбора
    user_choice = None
    if len(context.args) >= 2:
        choice = context.args[1].lower()
        if choice in ['гол', 'goal', 'г', 'g']:
            user_choice = "goal"
        elif choice in ['мимо', 'miss', 'м', 'm']:
            user_choice = "miss"

    # Если выбор указан — сразу запускаем игру
    if user_choice:
        await process_football_final(update, context, user, user_data, bet, user_choice, original_msg_id)
        return

    # Если выбор не указан — показываем кнопки
    game_data_key = f'fb_{user.id}_{update.message.chat_id}_{original_msg_id}'
    context.user_data[game_data_key] = {
        'bet': bet,
        'original_msg_id': original_msg_id,
        'user_id': user.id
    }

    keyboard = [
        [InlineKeyboardButton("⚽ Гол (×1.6)", callback_data=f"fb_choice_goal_{game_data_key}"),
         InlineKeyboardButton("❌ Мимо (×2.25)", callback_data=f"fb_choice_miss_{game_data_key}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    await update.message.reply_text(
        f"{user_link}\n"
        f"⚽ Футбол · выбери исход!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} Vscoin",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def process_football_final(update, context, user, user_data, bet, user_choice, original_msg_id):
    """Финальная обработка футбола"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Отправляем анимацию
    animation_msg = await context.bot.send_dice(
        chat_id=update.effective_chat.id,
        emoji="⚽",
        reply_to_message_id=original_msg_id
    )
    await asyncio.sleep(3)

    # Определяем результат (1-2 = мимо, 3-4-5 = гол)
    dice_value = animation_msg.dice.value
    is_actual_goal = (dice_value in [3, 4, 5])
    actual_result_text = "гол" if is_actual_goal else "мимо"
    
    choice_text = "гол" if user_choice == "goal" else "мимо"
    
    # Определяем победил ли игрок
    player_wins = (user_choice == "goal") == is_actual_goal

    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    if player_wins:
        multiplier = 1.6 if user_choice == "goal" else 2.25
        win_amount = int(bet * multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount

        result_message = (
            f"{user_link}\n"
            f"🔥 Футбол · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: ×{multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Итог: <code>{actual_result_text}</code>"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet

        result_message = (
            f"{user_link}\n"
            f"💥 Футбол · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Итог: <code>{actual_result_text}</code>"
        )

    # Сохраняем результат
    db.update_user(user.id, user_data)
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text=result_message,
        parse_mode=ParseMode.HTML,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def football_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок футбола"""
    query = update.callback_query
    await query.answer()

    user = query.from_user
    user_data = db.get_user(user.id)

    # Парсим данные
    data_parts = query.data.split('_')
    user_choice = data_parts[2]  # 'goal' или 'miss'
    game_data_key = '_'.join(data_parts[3:])

    # Проверяем данные игры
    if game_data_key not in context.user_data:
        await query.edit_message_text("❌ Сессия игры устарела. Начните заново.")
        return

    game_data = context.user_data[game_data_key]

    # Проверяем, совпадает ли пользователь
    if game_data.get('user_id') != user.id:
        await query.answer("❌ Эта игра начата другим пользователем.")
        return

    bet = game_data['bet']
    original_msg_id = game_data['original_msg_id']

    # Проверяем баланс
    if user_data['balance'] < bet:
        await query.edit_message_text("❌ Недостаточно средств!")
        return

    # Запускаем игру
    await process_football_final(update, context, user, user_data, bet, user_choice, original_msg_id)
    
    # Удаляем сообщение с кнопками
    await query.message.delete()
    
    # Удаляем данные игры
    del context.user_data[game_data_key]
async def basketball_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игра в баскетбол с новой логикой: 1,2,3 = мимо, 4,5 = гол"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    original_msg_id = update.message.message_id

    # Проверки
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!", reply_to_message_id=original_msg_id)
        return
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /баскетбол [ставка] (гол/мимо)", reply_to_message_id=original_msg_id)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        if bet <= 0 or user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Ошибка ставки! Доступно: {format_number(user_data['balance'])}", reply_to_message_id=original_msg_id)
            return
    except:
        await update.message.reply_text("❌ Используйте: /баскетбол 100", reply_to_message_id=original_msg_id)
        return

    # Обработка прямого выбора
    user_choice = None
    if len(context.args) >= 2:
        choice = context.args[1].lower()
        if choice in ['гол', 'goal', 'г', 'g']:
            user_choice = "goal"
        elif choice in ['мимо', 'miss', 'м', 'm']:
            user_choice = "miss"

    # Если выбор указан — сразу запускаем игру
    if user_choice:
        await process_basketball_final(update, context, user, user_data, bet, user_choice, original_msg_id)
        return

    # Если выбор не указан — показываем кнопки
    game_data_key = f'bb_{user.id}_{update.message.chat_id}_{original_msg_id}'
    context.user_data[game_data_key] = {
        'bet': bet,
        'original_msg_id': original_msg_id,
        'user_id': user.id
    }

    keyboard = [
        [InlineKeyboardButton("🏀 гол 2.4", callback_data=f"bb_choice_goal_{game_data_key}"),
         InlineKeyboardButton("❌ мимо 1.6", callback_data=f"bb_choice_miss_{game_data_key}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    await update.message.reply_text(
        f"{user_link}\n"
        f"🏀 Баскетбол · выбери исход!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} Vscoin",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def process_basketball_final(update, context, user, user_data, bet, user_choice, original_msg_id):
    """Финальная обработка баскетбола с НОВОЙ логикой: 1,2,3 = мимо, 4,5 = гол"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Отправляем анимацию
    animation_msg = await context.bot.send_dice(
        chat_id=update.effective_chat.id,
        emoji="🏀",
        reply_to_message_id=original_msg_id
    )
    await asyncio.sleep(4)

    # НОВАЯ ЛОГИКА: 1,2,3 = мимо, 4,5 = гол
    dice_value = animation_msg.dice.value
    is_actual_goal = (dice_value in [4, 5])  # 4 или 5 = ГОЛ
    actual_result_text = "гол" if is_actual_goal else "мимо"
    
    choice_text = "гол" if user_choice == "goal" else "мимо"
    
    # Определяем победил ли игрок
    player_wins = (user_choice == "goal") == is_actual_goal

    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    if player_wins:
        multiplier = 2.4 if user_choice == "goal" else 1.6
        win_amount = int(bet * multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount

        result_message = (
            f"{user_link}\n"
            f"🥳 Баскетбол · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: ×{multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Итог: <code>{actual_result_text}</code>"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet

        result_message = (
            f"{user_link}\n"
            f"😥 Баскетбол · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Итог: <code>{actual_result_text}</code>"
        )

    # Сохраняем результат
    db.update_user(user.id, user_data)
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text=result_message,
        parse_mode=ParseMode.HTML,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def basketball_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок баскетбола"""
    query = update.callback_query
    await query.answer()

    user = query.from_user
    user_data = db.get_user(user.id)

    # Парсим данные
    data_parts = query.data.split('_')
    user_choice = data_parts[2]  # 'goal' или 'miss'
    game_data_key = '_'.join(data_parts[3:])

    # Проверяем данные игры
    if game_data_key not in context.user_data:
        await query.edit_message_text("❌ Сессия игры устарела. Начните заново.")
        return

    game_data = context.user_data[game_data_key]

    # Проверяем, совпадает ли пользователь
    if game_data.get('user_id') != user.id:
        await query.answer("❌ Эта игра начата другим пользователем.")
        return

    bet = game_data['bet']
    original_msg_id = game_data['original_msg_id']

    # Проверяем баланс
    if user_data['balance'] < bet:
        await query.edit_message_text("❌ Недостаточно средств!")
        return

    # Запускаем игру
    await process_basketball_final(update, context, user, user_data, bet, user_choice, original_msg_id)
    
    # Удаляем сообщение с кнопками
    await query.message.delete()
    
    # Удаляем данные игры
    del context.user_data[game_data_key]


async def darts_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игра в дартс с анимацией 🎯"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    original_msg_id = update.message.message_id

    # Проверки
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!", reply_to_message_id=original_msg_id)
        return
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /дартс [ставка] (красное/белое/центр/мимо)", reply_to_message_id=original_msg_id)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        if bet <= 0 or user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Ошибка ставки! Доступно: {format_number(user_data['balance'])}", reply_to_message_id=original_msg_id)
            return
    except:
        await update.message.reply_text("❌ Используйте: /дартс 100", reply_to_message_id=original_msg_id)
        return

    # Обработка прямого выбора
    user_choice = None
    if len(context.args) >= 2:
        choice = ' '.join(context.args[1:]).lower()
        
        if choice in ['красное', 'красный', 'красн', 'red']:
            user_choice = "red"
        elif choice in ['белое', 'белый', 'бел', 'white']:
            user_choice = "white"
        elif choice in ['центр', 'центровое', 'center', 'mid']:
            user_choice = "center"
        elif choice in ['мимо', 'miss', 'промах']:
            user_choice = "miss"

    # Если выбор указан — сразу запускаем игру
    if user_choice:
        await process_darts_final(update, context, user, user_data, bet, user_choice, original_msg_id)
        return

    # Если выбор не указан — показываем кнопки
    game_data_key = f'dart_{user.id}_{update.message.chat_id}_{original_msg_id}'
    context.user_data[game_data_key] = {
        'bet': bet,
        'original_msg_id': original_msg_id,
        'user_id': user.id
    }

    keyboard = [
        [InlineKeyboardButton("🔴 Красное (х1.9)", callback_data=f"dart_choice_red_{game_data_key}")],
        [InlineKeyboardButton("⚪️ Белое (х2.5)", callback_data=f"dart_choice_white_{game_data_key}")],
        [InlineKeyboardButton("🎯 Центр (х5.5)", callback_data=f"dart_choice_center_{game_data_key}")],
        [InlineKeyboardButton("😯 Мимо (х5.5)", callback_data=f"dart_choice_miss_{game_data_key}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    await update.message.reply_text(
        f"{user_link}\n"
        f"🎯 Дартс · выбери исход!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} Vscoin\n\n"
        f"<code>🔰 Коэффициенты:</code>\n"
        f"<code>🔴 Красное (х1.9)</code>\n"
        f"<code>⚪️ Белое (х2.5)</code>\n"
        f"<code>🎯 Центр (х5.5)</code>\n"
        f"<code>😯 Мимо (х5.5)</code>",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def process_darts_final(update, context, user, user_data, bet, user_choice, original_msg_id):
    """Финальная обработка дартса"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Отправляем анимацию дартса
    animation_msg = await context.bot.send_dice(
        chat_id=update.effective_chat.id,
        emoji="🎯",
        reply_to_message_id=original_msg_id
    )
    await asyncio.sleep(4)  # Ждём завершения анимации дартса

    # Определяем результат из анимации
    dice_value = animation_msg.dice.value
    
    # Логика дартса в Telegram:
    # 1-5 = мимо (вне мишени)
    # 6 = попадание в центр
    # Но мы можем создать свою логику:
    # 1-2 = красное, 3-4 = белое, 5 = центр, 6 = мимо (или наоборот)
    
    # МОЯ ЛОГИКА для разнообразия:
    # 1-2 = 🔴 Красное
    # 3-4 = ⚪️ Белое  
    # 5 = 🎯 Центр
    # 6 = 😯 Мимо (вне мишени)
    
    if dice_value in [1, 2]:
        actual_result = "red"
        actual_result_text = "красное 🔴"
    elif dice_value in [3, 4]:
        actual_result = "white"
        actual_result_text = "белое ⚪️"
    elif dice_value == 5:
        actual_result = "center"
        actual_result_text = "центр 🎯"
    else:  # dice_value == 6
        actual_result = "miss"
        actual_result_text = "мимо 😯"
    
    # Определяем выигрыш
    choice_text_map = {
        "red": "красное",
        "white": "белое", 
        "center": "центр",
        "miss": "мимо"
    }
    
    choice_text = choice_text_map.get(user_choice, "неизвестно")
    
    # Множители
    multipliers = {
        "red": 1.9,
        "white": 2.5,
        "center": 5.5,
        "miss": 5.5
    }
    
    # Определяем победил ли игрок
    player_wins = (user_choice == actual_result)

    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    if player_wins:
        multiplier = multipliers[user_choice]
        win_amount = int(bet * multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount

        result_message = (
            f"{user_link}\n"
            f"🎊 Дартс · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: х{multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Выпало: {actual_result_text}"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet

        result_message = (
            f"{user_link}\n"
            f"😣 Дартс · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Выпало: {actual_result_text}"
        )

    # Сохраняем результат
    db.update_user(user.id, user_data)
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text=result_message,
        parse_mode=ParseMode.HTML,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def darts_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок дартса"""
    query = update.callback_query
    await query.answer()

    user = query.from_user
    user_data = db.get_user(user.id)

    # Парсим данные
    data_parts = query.data.split('_')
    user_choice = data_parts[2]  # 'red', 'white', 'center', 'miss'
    game_data_key = '_'.join(data_parts[3:])

    # Проверяем данные игры
    if game_data_key not in context.user_data:
        await query.edit_message_text("❌ Сессия игры устарела. Начните заново.")
        return

    game_data = context.user_data[game_data_key]

    # Проверяем, совпадает ли пользователь
    if game_data.get('user_id') != user.id:
        await query.answer("❌ Эта игра начата другим пользователем.")
        return

    bet = game_data['bet']
    original_msg_id = game_data['original_msg_id']

    # Проверяем баланс
    if user_data['balance'] < bet:
        await query.edit_message_text("❌ Недостаточно средств!")
        return

    # Запускаем игру
    await process_darts_final(update, context, user, user_data, bet, user_choice, original_msg_id)
    
    # Удаляем сообщение с кнопками
    await query.message.delete()
    
    # Удаляем данные игры
    del context.user_data[game_data_key]

async def process_darts_final(update, context, user, user_data, bet, user_choice, original_msg_id):
    """Финальная обработка дартса с ИСПРАВЛЕННОЙ логикой"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Отправляем анимацию дартса
    animation_msg = await context.bot.send_dice(
        chat_id=update.effective_chat.id,
        emoji="🎯",
        reply_to_message_id=original_msg_id
    )
    await asyncio.sleep(4)

    # ИСПРАВЛЕННАЯ ЛОГИКА:
    # 6 = мимо
    # 5 = центр
    # 3-4 = белое
    # 1-2 = красное
    dice_value = animation_msg.dice.value
    
    if dice_value == 1:
        actual_result = "miss"
        actual_result_text = "мимо 😯"
    elif dice_value == 6:
        actual_result = "center"
        actual_result_text = "центр 🎯"
    elif dice_value in [3,5 ]:
        actual_result = "white"
        actual_result_text = "белое ⚪️"
    else: # dice_value in [1, 5]
        actual_result = "red"
        actual_result_text = "красное 🔴"
    
    # Определяем выигрыш
    choice_text_map = {
        "red": "красное",
        "white": "белое", 
        "center": "центр",
        "miss": "мимо"
    }
    
    choice_text = choice_text_map.get(user_choice, "неизвестно")
    
    # Множители
    multipliers = {
        "red": 1.9,
        "white": 2.5,
        "center": 5.5,
        "miss": 5.5
    }
    
    # Определяем победил ли игрок
    player_wins = (user_choice == actual_result)

    # Синий ник игрока (ссылка на профиль)
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    if player_wins:
        multiplier = multipliers[user_choice]
        win_amount = int(bet * multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount

        result_message = (
            f"{user_link}\n"
            f"🎊 Дартс · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: х{multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Выпало: {actual_result_text}"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet

        result_message = (
            f"{user_link}\n"
            f"😣 Дартс · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Выпало: {actual_result_text}"
        )

    # Сохраняем результат
    db.update_user(user.id, user_data)
    await context.bot.send_message(
        chat_id=update.effective_chat.id,
        text=result_message,
        parse_mode=ParseMode.HTML,
        reply_to_message_id=original_msg_id,
        disable_web_page_preview=True
    )

async def roulette_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("Вы забанены и не можете играть")
        return
    
    if len(context.args) < 2:
        await update.message.reply_text("Использование: 'рулетка [ставка] [цвет/число]'\nЦвет: к (красный) или ч (черный)\nЧисло: от 0 до 36")
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        choice = context.args[1].lower()
    except:
        await update.message.reply_text("Неверный формат ставки или выбора")
        return
    
    if bet <= 0:
        await update.message.reply_text("Ставка должна быть положительной")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text("Недостаточно средств")
        return
    
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    if choice in ['к', 'красный']:
        bet_type = 'red'
        multiplier = 2
    elif choice in ['ч', 'черный']:
        bet_type = 'black'
        multiplier = 2
    elif choice.isdigit() and 0 <= int(choice) <= 36:
        bet_type = 'number'
        choice_number = int(choice)
        multiplier = 36
    else:
        user_data['balance'] += bet
        db.update_user(user.id, user_data)
        await update.message.reply_text("Неверный тип ставки. Используйте: к (красный), ч (черный) или число от 0 до 36")
        return
    
    result_number = random.randint(0, 36)
    
    red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
    if result_number == 0:
        result_color = 'green'
    elif result_number in red_numbers:
        result_color = 'red'
    else:
        result_color = 'black'
    
    if bet_type == 'number':
        is_win = (choice_number == result_number)
    else:
        is_win = (bet_type == result_color)
    
    message = await update.message.reply_text("🎰 Крутим рулетку...")
    
    for _ in range(5):
        random_num = random.randint(0, 36)
        random_color = 'green' if random_num == 0 else 'red' if random_num in red_numbers else 'black'
        color_emoji = '🟢' if random_color == 'green' else '🔴' if random_color == 'red' else '⚫️'
        await message.edit_text(f"🎰 Рулетка крутится...\n\nВыпало: {random_num} {color_emoji}")
        await asyncio.sleep(0.5)
    
    result_color_emoji = '🟢' if result_color == 'green' else '🔴' if result_color == 'red' else '⚫️'
    
    if is_win:
        win_amount = int(bet * multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        
        result_text = (
            f"🎰 Рулетка\n\n"
            f"Ставка: {format_number(bet)} Vscoin\n"
            f"Ваш выбор: {choice}\n"
            f"Выпало: {result_number} {result_color_emoji}\n\n"
            f"Итог: победа! 🎉\n\n"
            f"💰 Выигрыш: {format_number(win_amount)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet
        
        result_text = (
            f"🎰 Рулетка\n\n"
            f"Ставка: {format_number(bet)} Vscoin\n"
            f"Ваш выбор: {choice}\n"
            f"Выпало: {result_number} {result_color_emoji}\n\n"
            f"Итог: проигрыш 😕\n\n"
            f"💸 Проигрыш: {format_number(bet)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    
    db.update_user(user.id, user_data)
    await message.edit_text(result_text)

async def twentyone_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Запуск игры 21 (двадцать одно)"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    original_msg_id = update.message.message_id

    # Проверки
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!", reply_to_message_id=original_msg_id)
        return
    
    if len(context.args) < 1:
        help_text = (
            "🍀 <b>21 (Двадцать одно)</b>\n"
            "Ставка: /21 [сумма]\n"
            "Наберите карт ближе к 21, чем у дилера!"
        )
        await update.message.reply_text(help_text, parse_mode=ParseMode.HTML, reply_to_message_id=original_msg_id)
        return

    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        if bet <= 0 or user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Ошибка! Доступно: {format_number(user_data['balance'])}", reply_to_message_id=original_msg_id)
            return
    except:
        await update.message.reply_text("❌ Используй: /21 100", reply_to_message_id=original_msg_id)
        return

    # Создаём ключ для игры
    game_key = f'twentyone_{user.id}_{original_msg_id}'
    
    # Создаём колоду
    suits = ['♠️', '♥️', '♦️', '♣️']
    ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
    deck = [f"{rank}{suit}" for suit in suits for rank in ranks]
    random.shuffle(deck)
    
    # Раздаём начальные карты
    player_cards = [deck.pop(), deck.pop()]
    dealer_cards = [deck.pop(), deck.pop()]
    
    # Сохраняем игру
    context.user_data[game_key] = {
        'bet': bet,
        'deck': deck,
        'player_cards': player_cards,
        'dealer_cards': dealer_cards,
        'player_score': calculate_score(player_cards),
        'dealer_score': calculate_score(dealer_cards),
        'game_state': 'player_turn',
        'original_msg_id': original_msg_id,
        'user_id': user.id,
        'game_active': True
    }

    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Показываем начальный экран
    keyboard = [
        [InlineKeyboardButton("🎮 Начать игру", callback_data=f"twentyone_start_{game_key}")],
        [InlineKeyboardButton("❌ Отменить", callback_data=f"twentyone_cancel_{game_key}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"{user.full_name}\n"
        f"🍀 21 · начни игру!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} VsCoin",
        reply_markup=reply_markup,
        reply_to_message_id=original_msg_id
    )

async def twentyone_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик всех callback игры 21"""
    query = update.callback_query
    await query.answer()
    
    data = query.data
    parts = data.split('_')
    action = parts[1]
    game_key = '_'.join(parts[2:])
    
    user = query.from_user
    user_data = db.get_user(user.id)
    
    # Получаем данные игры
    game_data = context.user_data.get(game_key)
    if not game_data:
        await query.edit_message_text("❌ Игра не найдена или завершена")
        return
    
    if game_data['user_id'] != user.id:
        await query.answer("❌ Это не ваша игра")
        return
    
    if action == "start":
        await twentyone_play_round(query, context, game_data, game_key, user, user_data)
    
    elif action == "cancel":
        # Возвращаем ставку
        user_data['balance'] += game_data['bet']
        db.update_user(user.id, user_data)
        del context.user_data[game_key]
        await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
    
    elif action == "hit":
        await twentyone_hit(query, context, game_data, game_key, user, user_data)
    
    elif action == "stand":
        await twentyone_stand(query, context, game_data, game_key, user, user_data)
    
    elif action == "double":
        await twentyone_double(query, context, game_data, game_key, user, user_data)

async def twentyone_play_round(query, context, game_data, game_key, user, user_data):
    """Показать текущий раунд игры 21"""
    # Форматируем карты для отображения
    player_cards_display = ' • '.join(game_data['player_cards'])
    dealer_cards_display = game_data['dealer_cards'][0] + ' • ❓'
    
    player_score = game_data['player_score']
    
    # Создаем клавиатуру с кнопками действий
    keyboard = []
    
    # Кнопки для игрока (если не перебор)
    if player_score <= 21:
        keyboard.append([
            InlineKeyboardButton("➕ Ещё", callback_data=f"twentyone_hit_{game_key}"),
            InlineKeyboardButton("⛔ Хватит", callback_data=f"twentyone_stand_{game_key}")
        ])
        
        # Кнопка удвоения (только если 2 карты и баланс позволяет)
        if len(game_data['player_cards']) == 2 and user_data['balance'] >= game_data['bet']:
            keyboard.append([InlineKeyboardButton("💰 Удвоить (x2)", callback_data=f"twentyone_double_{game_key}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"{user.full_name}\n"
        f"🍀 21 · игра идёт\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n\n"
        f"🤵‍♂ Дилер:\n"
        f"{dealer_cards_display}\n"
        f"············\n"
        f"🫵 Ты:\n"
        f"{player_cards_display} | {player_score}\n\n"
        f"Выбери действие:",
        reply_markup=reply_markup
    )

async def twentyone_hit(query, context, game_data, game_key, user, user_data):
    """Игрок берет еще карту"""
    # Добавляем карту игроку
    game_data['player_cards'].append(game_data['deck'].pop())
    game_data['player_score'] = calculate_score(game_data['player_cards'])
    
    # Проверяем перебор
    if game_data['player_score'] > 21:
        await twentyone_bust(query, context, game_data, game_key, user, user_data)
    else:
        context.user_data[game_key] = game_data
        await twentyone_play_round(query, context, game_data, game_key, user, user_data)

async def twentyone_stand(query, context, game_data, game_key, user, user_data):
    """Игрок останавливается, ход дилера"""
    # Дилер берет карты по правилам (до 17)
    while game_data['dealer_score'] < 17:
        game_data['dealer_cards'].append(game_data['deck'].pop())
        game_data['dealer_score'] = calculate_score(game_data['dealer_cards'])
    
    await twentyone_show_result(query, context, game_data, game_key, user, user_data)

async def twentyone_double(query, context, game_data, game_key, user, user_data):
    """Удвоение ставки"""
    # Проверяем баланс
    if user_data['balance'] < game_data['bet']:
        await query.answer("❌ Недостаточно средств для удвоения")
        return
    
    # Удваиваем ставку
    user_data['balance'] -= game_data['bet']
    game_data['bet'] *= 2
    
    # Игрок берет одну карту
    game_data['player_cards'].append(game_data['deck'].pop())
    game_data['player_score'] = calculate_score(game_data['player_cards'])
    
    # Сохраняем изменения
    db.update_user(user.id, user_data)
    
    # Проверяем перебор
    if game_data['player_score'] > 21:
        await twentyone_bust(query, context, game_data, game_key, user, user_data)
    else:
        # Дилер берет карты
        while game_data['dealer_score'] < 17:
            game_data['dealer_cards'].append(game_data['deck'].pop())
            game_data['dealer_score'] = calculate_score(game_data['dealer_cards'])
        
        await twentyone_show_result(query, context, game_data, game_key, user, user_data)

async def twentyone_bust(query, context, game_data, game_key, user, user_data):
    """Игрок проиграл (перебор)"""
    user_data['games_played'] += 1
    user_data['losses'] += 1
    user_data['lost_amount'] += game_data['bet']
    
    # Форматируем карты для отображения
    player_cards_display = ' • '.join(game_data['player_cards'])
    dealer_cards_display = ' • '.join(game_data['dealer_cards'])
    
    await query.edit_message_text(
        f"{user.full_name}\n"
        f"😥 21 · Проигрыш!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n\n"
        f"🤵‍♂ Дилер:\n"
        f"{dealer_cards_display} | {game_data['dealer_score']}\n"
        f"············\n"
        f"🫵 Ты:\n"
        f"{player_cards_display} | {game_data['player_score']}\n\n"
        f"😔 Не повезло! У дилера больше."
    )
    
    # Сохраняем изменения и очищаем игру
    db.update_user(user.id, user_data)
    del context.user_data[game_key]

async def twentyone_show_result(query, context, game_data, game_key, user, user_data):
    """Показать результат игры"""
    player_score = game_data['player_score']
    dealer_score = game_data['dealer_score']
    
    # Форматируем карты для отображения
    player_cards_display = ' • '.join(game_data['player_cards'])
    dealer_cards_display = ' • '.join(game_data['dealer_cards'])
    
    # Определяем результат
    if dealer_score > 21:
        # Дилер перебор - игрок выиграл
        multiplier = 1.97  # Коэффициент выигрыша
        win_amount = int(game_data['bet'] * multiplier)
        
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount - game_data['bet']
        
        result_text = (
            f"{user.full_name}\n"
            f"🤯 21 · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n"
            f"💰 Выигрыш: x{multiplier} / {format_number(win_amount)} VsCoin\n\n"
            f"🤵‍♂ Дилер:\n"
            f"{dealer_cards_display} | {dealer_score}\n"
            f"············\n"
            f"🫵 Ты:\n"
            f"{player_cards_display} | {player_score}\n\n"
            f"🎉 Ты победил! У дилера перебор."
        )
        
    elif player_score > dealer_score:
        # Игрок выиграл
        multiplier = 1.97
        win_amount = int(game_data['bet'] * multiplier)
        
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount - game_data['bet']
        
        result_text = (
            f"{user.full_name}\n"
            f"🤯 21 · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n"
            f"💰 Выигрыш: x{multiplier} / {format_number(win_amount)} VsCoin\n\n"
            f"🤵‍♂ Дилер:\n"
            f"{dealer_cards_display} | {dealer_score}\n"
            f"············\n"
            f"🫵 Ты:\n"
            f"{player_cards_display} | {player_score}\n\n"
            f"🎉 Ты победил! У тебя больше очков."
        )
        
    elif player_score == dealer_score:
        # Ничья
        user_data['balance'] += game_data['bet']  # Возвращаем ставку
        
        result_text = (
            f"{user.full_name}\n"
            f"🤝 21 · Ничья!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n\n"
            f"🤵‍♂ Дилер:\n"
            f"{dealer_cards_display} | {dealer_score}\n"
            f"············\n"
            f"🫵 Ты:\n"
            f"{player_cards_display} | {player_score}\n\n"
            f"🤝 Равный счёт! Ставка возвращена."
        )
        
    else:
        # Дилер выиграл
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += game_data['bet']
        
        result_text = (
            f"{user.full_name}\n"
            f"😥 21 · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(game_data['bet'])} VsCoin\n\n"
            f"🤵‍♂ Дилер:\n"
            f"{dealer_cards_display} | {dealer_score}\n"
            f"············\n"
            f"🫵 Ты:\n"
            f"{player_cards_display} | {player_score}\n\n"
            f"😔 Не повезло! У дилера больше."
        )
    
    await query.edit_message_text(result_text)
    
    # Сохраняем изменения и очищаем игру
    db.update_user(user.id, user_data)
    del context.user_data[game_key]

# Функция calculate_score уже есть в вашем коде, убедитесь что она работает правильно:
def calculate_score(cards):
    """Рассчитать сумму очков в картах"""
    score = 0
    aces = 0
    
    for card in cards:
        # Извлекаем ранг карты (убираем эмодзи масти)
        rank = card[:-2] if len(card) > 2 else card[:-1]
        
        if rank in ['J', 'Q', 'K']:
            score += 10
        elif rank == 'A':
            aces += 1
            score += 11
        else:
            score += int(rank)
    
    # Корректируем тузы если сумма > 21
    while score > 21 and aces > 0:
        score -= 10  # Изменяем туз с 11 на 1
        aces -= 1
    
    return score

# ============== КУБИК - ИСПРАВЛЕННАЯ ВЕРСИЯ ==============

async def cubes_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игра в кубик"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Если нет аргументов - показываем меню с выбором ставки
    if len(context.args) < 1:
        keyboard = [
            [InlineKeyboardButton("🎲 Играть (ввести ставку)", callback_data="cubes_start")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await update.message.reply_text(
            f"🎲 <b>Игра в кубик</b>\n\n"
            f"📊 <b>Коэффициенты:</b>\n"
            f"<code>🎯 Число (1-6) - ×5.8</code>\n"
            f"<code>⚫ Четное - ×1.9</code>\n"
            f"<code>⚪ Нечетное - ×1.9</code>\n"
            f"<code>🎯 Равно 3 - ×5.8</code>\n"
            f"<code>📉 Меньше 3 - ×2.7</code>\n"
            f"<code>📈 Больше 3 - ×2.1</code>\n\n"
            f"<b>Использование:</b>\n"
            f"<code>/кубик [ставка]</code> - затем выберите режим\n"
            f"Или сразу: <code>/кубик [ставка] [число/режим]</code>",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # Получаем ставку
    try:
        bet_text = context.args[0]
        bet = parse_bet(bet_text, user_data['balance'])
        
        if bet <= 0:
            await update.message.reply_text("❌ Ставка должна быть больше 0!")
            return
            
        if user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])}")
            return
    except Exception as e:
        print(f"Ошибка парсинга ставки: {e}")
        await update.message.reply_text("❌ Неверный формат ставки! Используйте: /кубик [ставка]")
        return
    
    # Если есть второй аргумент - сразу запускаем игру
    if len(context.args) >= 2:
        mode_text = ' '.join(context.args[1:]).lower()
        
        # Обработка разных форматов
        if mode_text.isdigit() and 1 <= int(mode_text) <= 6:
            number = int(mode_text)
            await play_cubes_direct(update, context, user, user_data, bet, 'number', number)
        elif mode_text in ['четное', 'чет', 'чётное', 'четн', 'чёт', 'even']:
            await play_cubes_direct(update, context, user, user_data, bet, 'even', None)
        elif mode_text in ['нечетное', 'нечет', 'нечётное', 'нечетн', 'нечёт', 'odd']:
            await play_cubes_direct(update, context, user, user_data, bet, 'odd', None)
        elif mode_text in ['равно3', 'равно 3', '=3', '==3', 'равно3️⃣', 'equals3']:
            await play_cubes_direct(update, context, user, user_data, bet, 'equals_3', None)
        elif mode_text in ['меньше3', 'меньше 3', '<3', 'меньше3️⃣', 'мен3', 'less3']:
            await play_cubes_direct(update, context, user, user_data, bet, 'less_3', None)
        elif mode_text in ['больше3', 'больше 3', '>3', 'больше3️⃣', 'бол3', 'more3']:
            await play_cubes_direct(update, context, user, user_data, bet, 'more_3', None)
        else:
            await update.message.reply_text("❌ Неизвестный режим. Используйте: число (1-6), четное, нечетное, равно3, меньше3, больше3")
        return
    
    # Показываем выбор режима с выбранной ставкой
    await show_mode_selection(update.message, user, bet)

async def show_mode_selection(message, user, bet):
    """Показать выбор режима игры"""
    keyboard = [
        [InlineKeyboardButton("🎲 Выбрать число (1-6)", callback_data=f"cubes_mode_number_{bet}")],
        [InlineKeyboardButton("⚫ Четное (×1.9)", callback_data=f"cubes_mode_even_{bet}")],
        [InlineKeyboardButton("⚪ Нечетное (×1.9)", callback_data=f"cubes_mode_odd_{bet}")],
        [InlineKeyboardButton("🎯 Равно 3 (×5.8)", callback_data=f"cubes_mode_equals3_{bet}")],
        [InlineKeyboardButton("📉 Меньше 3 (×2.7)", callback_data=f"cubes_mode_less3_{bet}")],
        [InlineKeyboardButton("📈 Больше 3 (×2.1)", callback_data=f"cubes_mode_more3_{bet}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await message.reply_text(
        f"{user.full_name}\n"
        f"🎲 Кубик · выбери режим!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} Vscoin\n\n"
        f"Выберите вариант игры:",
        reply_markup=reply_markup
    )

async def cubes_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок кубика"""
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    user_data = db.get_user(user.id)
    data = query.data
    
    # Начало игры - запрос ставки
    if data == "cubes_start":
        await query.edit_message_text(
            f"🎲 <b>Введите ставку:</b>\n\n"
            f"Используйте команду:\n"
            f"<code>/кубик [ставка]</code>\n\n"
            f"Например: <code>/кубик 100</code>",
            parse_mode=ParseMode.HTML
        )
        return
    
    # Выбор режима (number, even, odd, equals3, less3, more3)
    if data.startswith("cubes_mode_"):
        try:
            parts = data.split('_')
            mode = parts[2]  # number, even, odd, equals3, less3, more3
            bet = int(parts[3])
            
            # Проверяем баланс
            if user_data['balance'] < bet:
                await query.answer(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])}", show_alert=True)
                return
            
            # Если выбран режим "число" - показываем выбор числа
            if mode == "number":
                keyboard = [
                    [
                        InlineKeyboardButton("1️⃣", callback_data=f"cubes_play_number_{bet}_1"),
                        InlineKeyboardButton("2️⃣", callback_data=f"cubes_play_number_{bet}_2"),
                        InlineKeyboardButton("3️⃣", callback_data=f"cubes_play_number_{bet}_3")
                    ],
                    [
                        InlineKeyboardButton("4️⃣", callback_data=f"cubes_play_number_{bet}_4"),
                        InlineKeyboardButton("5️⃣", callback_data=f"cubes_play_number_{bet}_5"),
                        InlineKeyboardButton("6️⃣", callback_data=f"cubes_play_number_{bet}_6")
                    ],
                    [InlineKeyboardButton("🔙 Назад", callback_data=f"cubes_back_{bet}")]
                ]
                reply_markup = InlineKeyboardMarkup(keyboard)
                
                await query.edit_message_text(
                    f"{user.full_name}\n"
                    f"🎲 Кубик · выбери число!\n"
                    f"·····················\n"
                    f"💸 Ставка: {format_number(bet)} Vscoin\n\n"
                    f"Выберите число от 1 до 6 (×5.8):",
                    reply_markup=reply_markup
                )
            else:
                # Для других режимов - сразу запускаем игру
                mode_map = {
                    'even': ('even', None),
                    'odd': ('odd', None),
                    'equals3': ('equals_3', None),
                    'less3': ('less_3', None),
                    'more3': ('more_3', None)
                }
                
                if mode in mode_map:
                    actual_mode, number = mode_map[mode]
                    await play_cubes_game(query, context, user, user_data, bet, actual_mode, number)
                else:
                    await query.answer("❌ Неизвестный режим", show_alert=True)
                    
        except Exception as e:
            print(f"Ошибка в cubes_mode_: {e}")
            await query.answer("❌ Ошибка в данных", show_alert=True)
        return
    
    # Выбор конкретного числа
    if data.startswith("cubes_play_number_"):
        try:
            parts = data.split('_')
            bet = int(parts[3])
            number = int(parts[4])
            
            if number < 1 or number > 6:
                await query.answer("❌ Число должно быть от 1 до 6", show_alert=True)
                return
            
            # Проверяем баланс
            if user_data['balance'] < bet:
                await query.answer(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])}", show_alert=True)
                return
            
            # Запускаем игру
            await play_cubes_game(query, context, user, user_data, bet, 'number', number)
            
        except Exception as e:
            print(f"Ошибка в cubes_play_number_: {e}")
            await query.answer("❌ Ошибка в данных", show_alert=True)
        return
    
    # Возврат к выбору режима
    if data.startswith("cubes_back_"):
        try:
            bet = int(data.split('_')[2])
            await show_mode_selection(query.message, user, bet)
        except:
            await query.answer("❌ Ошибка", show_alert=True)
        return

async def play_cubes_game(query, context, user, user_data, bet, mode, number=None):
    """Запуск игры из callback"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Удаляем сообщение с кнопками
    await query.message.delete()
    
    # Отправляем анимацию кубика
    animation_msg = await context.bot.send_dice(
        chat_id=query.message.chat_id,
        emoji="🎲"
    )
    await asyncio.sleep(4)
    
    # Обрабатываем результат
    await process_cubes_result(query, context, user, user_data, bet, mode, number, animation_msg.dice.value)

async def play_cubes_direct(update: Update, context: ContextTypes.DEFAULT_TYPE, user, user_data, bet, mode, number=None):
    """Прямой запуск игры из команды"""
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Отправляем анимацию кубика
    animation_msg = await context.bot.send_dice(
        chat_id=update.effective_chat.id,
        emoji="🎲"
    )
    await asyncio.sleep(4)
    
    # Обрабатываем результат
    await process_cubes_result_message(update.message, context, user, user_data, bet, mode, number, animation_msg.dice.value)

async def process_cubes_result(query, context, user, user_data, bet, mode, number, dice_value):
    """Обработка результата из callback"""
    result_emoji = get_number_emoji(dice_value)
    choice_text = get_choice_text(mode, number)
    
    # Проверяем выигрыш
    is_win, win_multiplier = check_win(mode, number, dice_value)
    
    # Результат
    if is_win:
        win_amount = int(bet * win_multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += (win_amount - bet)
        
        message = (
            f"{user.full_name}\n"
            f"🎉 Кубик · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: ×{win_multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Выпало: {result_emoji}"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet
        
        message = (
            f"{user.full_name}\n"
            f"🛑 Кубик · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Выпало: {result_emoji}"
        )
    
    db.update_user(user.id, user_data)
    
    # Отправляем результат
    await context.bot.send_message(
        chat_id=query.message.chat_id,
        text=message
    )

async def process_cubes_result_message(message, context, user, user_data, bet, mode, number, dice_value):
    """Обработка результата из сообщения"""
    result_emoji = get_number_emoji(dice_value)
    choice_text = get_choice_text(mode, number)
    
    # Проверяем выигрыш
    is_win, win_multiplier = check_win(mode, number, dice_value)
    
    # Результат
    if is_win:
        win_amount = int(bet * win_multiplier)
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += (win_amount - bet)
        
        message_text = (
            f"{user.full_name}\n"
            f"🎉 Кубик · Победа! ✅\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"💰 Выигрыш: ×{win_multiplier} / {format_number(win_amount)} Vscoin\n"
            f"············\n"
            f"⚡️ Выпало: {result_emoji}"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet
        
        message_text = (
            f"{user.full_name}\n"
            f"🛑 Кубик · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(bet)} Vscoin\n"
            f"🎲 Выбрано: {choice_text}\n"
            f"············\n"
            f"⚡️ Выпало: {result_emoji}"
        )
    
    db.update_user(user.id, user_data)
    
    # Отправляем результат
    await message.reply_text(message_text)

def check_win(mode, number, dice_value):
    """Проверить выигрыш"""
    if mode == 'number':
        return (dice_value == number), 5.8
    elif mode == 'even':
        return (dice_value % 2 == 0), 1.9
    elif mode == 'odd':
        return (dice_value % 2 == 1), 1.9
    elif mode == 'equals_3':
        return (dice_value == 3), 5.8
    elif mode == 'less_3':
        return (dice_value < 3), 2.7
    elif mode == 'more_3':
        return (dice_value > 3), 2.1
    return False, 1.0

def get_choice_text(mode, number):
    """Получить текст выбора"""
    if mode == 'number':
        return f"{get_number_emoji(number)} (число {number})"
    elif mode == 'even':
        return "четное ⚫"
    elif mode == 'odd':
        return "нечетное ⚪"
    elif mode == 'equals_3':
        return "равно 3 🎯"
    elif mode == 'less_3':
        return "меньше 3 📉"
    elif mode == 'more_3':
        return "больше 3 📈"
    return "неизвестно"

def get_number_emoji(number):
    """Получить эмодзи для числа"""
    emoji_map = {
        1: "1️⃣",
        2: "2️⃣",
        3: "3️⃣",
        4: "4️⃣",
        5: "5️⃣",
        6: "6️⃣"
    }
    return emoji_map.get(number, "🎲")

async def allin_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("Вы забанены и не можете играть")
        return
    
    bet = user_data['balance']
    
    if bet <= 0:
        await update.message.reply_text("Недостаточно средств")
        return
    
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    is_win = random.random() < 0.5
    
    if is_win:
        win_amount = bet * 2
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        
        result_text = (
            f"💰 Игра 'На все'\n\n"
            f"Ставка: {format_number(bet)} Vscoin\n\n"
            f"🎉 Поздравляем! Вы выиграли!\n"
            f"💰 Выигрыш: {format_number(win_amount)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet
        
        result_text = (
            f"💰 Игра 'На все'\n\n"
            f"Ставка: {format_number(bet)} Vscoin\n\n"
            f"💸 К сожалению, вы проиграли\n"
            f"💸 Проигрыш: {format_number(bet)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    
    db.update_user(user.id, user_data)
    await update.message.reply_text(result_text)


# 1. Обновите константы (добавьте в начало файла после других констант):
GOLD_MULTIPLIERS = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]

# 2. Новая функция gold_game:
async def gold_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Игра в золото с новым дизайном"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены и не можете играть!")
        return
    
    if len(context.args) < 1:
        help_text = (
            "🟡 <b>Игра 'Золото'</b>\n\n"
            "🎯 <b>Правила:</b>\n"
            "• В каждой строке скрыты золото (💰) и петарда (🧨)\n"
            "• Выбирайте лево или право чтобы найти золото\n"
            "• Чем дальше продвинетесь, тем выше множитель!\n\n"
            "📝 <b>Формат:</b> <code>/золото [ставка]</code>\n\n"
            "<b>Примеры:</b>\n"
            "<code>/золото 100</code>\n"
            "<code>/золото 1к</code>"
        )
        await update.message.reply_text(help_text, parse_mode=ParseMode.HTML)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
    except:
        await update.message.reply_text("❌ Неверный формат ставки! Пример: /золото 100")
        return
    
    if bet <= 0:
        await update.message.reply_text("❌ Ставка должна быть больше 0!")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])}")
        return
    
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Генерируем позиции петард для 12 уровней (случайно лево или право)
    mine_positions = [random.choice([0, 1]) for _ in range(12)]  # 0 = петарда слева, 1 = петарда справа
    
    # Создаем игру
    game_data = {
        'type': 'gold',
        'bet': bet,
        'mine_positions': mine_positions,
        'current_level': 0,  # начинаем с уровня 0
        'selected_cells': [],  # выбранные клетки на каждом уровне
        'game_state': 'playing',
        'user_id': user.id,
        'message_id': None
    }
    
    # Сохраняем игру в context для callback
    game_id = f"gold_{user.id}_{int(time.time())}"
    context.user_data[game_id] = game_data
    
    # Сохраняем игру в БД
    user_data['active_game'] = game_data
    db.update_user(user.id, user_data)
    
    # Создаем сообщение с полем
    await show_gold_game(update, context, user, game_data, game_id)

async def show_gold_game(update: Update, context: ContextTypes.DEFAULT_TYPE, user, game_data, game_id=None):
    """Показать текущее состояние игры в золото"""
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    # Текст сообщения
    if game_data['current_level'] == 0:
        status = "🟡 Золото · начни игру!"
        current_multiplier = 1
    else:
        current_multiplier = GOLD_MULTIPLIERS[game_data['current_level'] - 1]
        win_amount = int(game_data['bet'] * current_multiplier)
        status = f"⚜️ Золото · игра идёт.\n·····················\n💸 Ставка: {game_data['bet']} VsCoin\n💰 Выигрыш: х{current_multiplier} / {format_number(win_amount)} VsCoin"
    
    message_text = f"{user_link}\n{status}\n\n"
    
    # Создаем поле 12 строк
    for level in range(11, -1, -1):  # от 11 до 0 (сверху вниз)
        if level < game_data['current_level']:
            # Пройденные уровни
            if game_data['selected_cells'][level] == 'left':
                # Игрок выбрал лево
                if game_data['mine_positions'][level] == 0:
                    # Петарда была слева -> но игрок выбрал лево и проиграл бы
                    left_cell = '🧨'
                    right_cell = '💸'
                else:
                    # Золото было справа -> игрок выбрал лево и проиграл бы
                    left_cell = '💸'
                    right_cell = '🧨'
            else:
                # Игрок выбрал право
                if game_data['mine_positions'][level] == 0:
                    # Петарда слева, золото справа -> успех
                    left_cell = '🧨'
                    right_cell = '💰'
                else:
                    # Петарда справа -> игрок выбрал право и проиграл бы
                    left_cell = '💸'
                    right_cell = '🧨'
        elif level == game_data['current_level'] and game_data['game_state'] == 'playing':
            # Текущий уровень, нужно сделать выбор
            left_cell = '❓'
            right_cell = '❓'
        else:
            # Будущие уровни - не выбраны игроком
            left_cell = '❓'
            right_cell = '❓'
        
        multiplier = GOLD_MULTIPLIERS[level]
        win_for_level = format_number(int(game_data['bet'] * multiplier))
        message_text += f"|{left_cell}|{right_cell}| {win_for_level} VsCoin ({multiplier}x)\n"
    
    # Создаем клавиатуру
    keyboard = []
    
    if game_data['game_state'] == 'playing':
        # Кнопки для выбора
        row1 = []
        row2 = []
        
        if game_data['current_level'] < 12:
            # Добавляем game_id в callback_data
            row1.append(InlineKeyboardButton("⬅️ Лево", callback_data=f"gold_left_{game_id}"))
            row1.append(InlineKeyboardButton("➡️ Право", callback_data=f"gold_right_{game_id}"))
        
        if row1:
            keyboard.append(row1)
        
        if game_data['current_level'] > 0:
            current_multiplier = GOLD_MULTIPLIERS[game_data['current_level'] - 1]
            win_amount = int(game_data['bet'] * current_multiplier)
            row2.append(InlineKeyboardButton(f"💰 Забрать {format_number(win_amount)} VsCoin", callback_data=f"gold_cashout_{game_id}"))
        
        if row2:
            keyboard.append(row2)
        
        keyboard.append([InlineKeyboardButton("❌ Отменить", callback_data=f"gold_cancel_{game_id}")])
    
    elif game_data['game_state'] == 'won':
        keyboard.append([InlineKeyboardButton("✅ Игра завершена", callback_data=f"gold_finished_{game_id}")])
    elif game_data['game_state'] == 'lost':
        keyboard.append([InlineKeyboardButton("💥 Игра завершена", callback_data=f"gold_finished_{game_id}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    if update.callback_query:
        await update.callback_query.edit_message_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
    else:
        message = await update.message.reply_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        # Сохраняем ID сообщения
        if game_id and game_id in context.user_data:
            context.user_data[game_id]['message_id'] = message.message_id

# 3. Новый обработчик gold_callback:
async def gold_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик игры в золото"""
    query = update.callback_query
    user = query.from_user
    data = query.data
    
    await query.answer()
    
    # Извлекаем action и game_id из callback_data
    parts = data.split('_')
    if len(parts) < 3:
        await query.answer("❌ Ошибка в данных игры")
        return
    
    action = parts[1]  # left, right, cashout, cancel, finished
    game_id = '_'.join(parts[2:])  # gold_123456789_123456789
    
    # Получаем данные игры из context
    if game_id not in context.user_data:
        await query.answer("❌ Игра не найдена или устарела")
        return
    
    game_data = context.user_data[game_id]
    
    # Проверяем, что это игра пользователя
    if game_data.get('user_id') != user.id:
        await query.answer("❌ Это не ваша игра")
        return
    
    user_data = db.get_user(user.id)
    
    # Обработка действий
    if action == "cancel":
        # Отмена игры
        user_data['balance'] += game_data['bet']
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        # Удаляем игру из context
        if game_id in context.user_data:
            del context.user_data[game_id]
        
        await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
        return
    
    elif action == "cashout":
        # Забрать выигрыш
        if game_data['current_level'] == 0:
            await query.answer("❌ Сначала сделайте хотя бы один выбор!")
            return
            
        current_multiplier = GOLD_MULTIPLIERS[game_data['current_level'] - 1]
        win_amount = int(game_data['bet'] * current_multiplier)
        
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        
        # Обновляем данные
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        # ПОКАЗЫВАЕМ ПОЛНУЮ ТАБЛИЦУ ПРИ ЗАВЕРШЕНИИ
        user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        message_text = f"{user_link}\n🎉 Золото · Победа!\n·····················\n💸 Ставка: {game_data['bet']} VsCoin\n💰 Выигрыш: {format_number(win_amount)} VsCoin\n⚜️ Пройдено: {game_data['current_level']} из 12\n\n"
        
        # ПОЛНАЯ ТАБЛИЦА: показываем все 12 уровней с реальным расположением
        for level in range(11, -1, -1):  # от 11 до 0
            # Определяем что было на этом уровне
            if game_data['mine_positions'][level] == 0:
                # Петарда слева, золото справа
                gold_left = False
                gold_right = True
            else:
                # Петарда справа, золото слева
                gold_left = True
                gold_right = False
            
            # Определяем выбрал ли игрок этот уровень и что выбрал
            if level < game_data['current_level']:
                # Игрок прошел этот уровень
                if game_data['selected_cells'][level] == 'left':
                    # Игрок выбрал лево
                    if gold_left:
                        # Золото было слева -> игрок нашел золото
                        left_cell = '💰'
                        right_cell = '🧨'
                    else:
                        # Петарда была слева -> игрок проиграл бы, но cashout остановил
                        left_cell = '🧨'
                        right_cell = '💸'
                else:
                    # Игрок выбрал право
                    if gold_right:
                        # Золото было справа -> игрок нашел золото
                        left_cell = '🧨'
                        right_cell = '💰'
                    else:
                        # Петарда была справа -> игрок проиграл бы, но cashout остановил
                        left_cell = '💸'
                        right_cell = '🧨'
            else:
                # Игрок не проходил этот уровень
                if gold_left:
                    left_cell = '💸'  # Золото было слева (но игрок не выбирал)
                    right_cell = '🧨'  # Петарда справа
                else:
                    left_cell = '🧨'  # Петарда слева
                    right_cell = '💸'  # Золото было справа (но игрок не выбирал)
            
            multiplier = GOLD_MULTIPLIERS[level]
            win_for_level = format_number(int(game_data['bet'] * multiplier))
            message_text += f"|{left_cell}|{right_cell}| {win_for_level} VsCoin ({multiplier}x)\n"
        
        keyboard = [[InlineKeyboardButton("✅ Игра завершена", callback_data=f"gold_finished_{game_id}")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    elif action in ["left", "right"]:
        # Выбор лево/право
        is_left = (action == "left")
        current_level = game_data['current_level']
        
        if current_level >= 12:
            await query.answer("❌ Игра уже завершена")
            return
        
        # Проверяем выбор
        mine_position = game_data['mine_positions'][current_level]
        is_mine = (is_left and mine_position == 0) or (not is_left and mine_position == 1)
        
        # Сохраняем выбор
        game_data['selected_cells'].append('left' if is_left else 'right')
        
        if is_mine:
            # ПРОИГРЫШ - нашли петарду
            user_data['games_played'] += 1
            user_data['losses'] += 1
            user_data['lost_amount'] += game_data['bet']
            game_data['game_state'] = 'lost'
            
            # Обновляем данные
            user_data['active_game'] = None
            db.update_user(user.id, user_data)
            
            # ПОКАЗЫВАЕМ ПОЛНУЮ ТАБЛИЦУ ПРИ ПРОИГРЫШЕ
            user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
            message_text = f"{user_link}\n💥 Золото · Проигрыш!\n·····················\n💸 Ставка: {game_data['bet']} VsCoin\n⚜️ Пройдено: {current_level + 1} из 12\n\n"
            
            # ПОЛНАЯ ТАБЛИЦА: показываем все 12 уровней с реальным расположением
            for level in range(11, -1, -1):  # от 11 до 0
                # Определяем что было на этом уровне
                if game_data['mine_positions'][level] == 0:
                    # Петарда слева, золото справа
                    gold_left = False
                    gold_right = True
                else:
                    # Петарда справа, золото слева
                    gold_left = True
                    gold_right = False
                
                # Определяем выбрал ли игрок этот уровень и что выбрал
                if level < current_level:
                    # Игрок прошел этот уровень до проигрыша
                    if game_data['selected_cells'][level] == 'left':
                        # Игрок выбрал лево
                        if gold_left:
                            # Золото было слева -> игрок нашел золото
                            left_cell = '💰'
                            right_cell = '🧨'
                        else:
                            # Петарда была слева -> игрок проиграл бы
                            left_cell = '🧨'
                            right_cell = '💸'
                    else:
                        # Игрок выбрал право
                        if gold_right:
                            # Золото было справа -> игрок нашел золото
                            left_cell = '🧨'
                            right_cell = '💰'
                        else:
                            # Петарда была справа -> игрок проиграл бы
                            left_cell = '💸'
                            right_cell = '🧨'
                elif level == current_level:
                    # Текущий уровень с проигрышем
                    if is_left:
                        left_cell = '💥'
                        # Показываем что было справа
                        right_cell = '💸' if gold_right else '🧨'
                    else:
                        right_cell = '💥'
                        # Показываем что было слева
                        left_cell = '💸' if gold_left else '🧨'
                else:
                    # Будущие уровни - не пройдены игроком
                    if gold_left:
                        left_cell = '💸'  # Золото было слева
                        right_cell = '🧨'  # Петарда справа
                    else:
                        left_cell = '🧨'  # Петарда слева
                        right_cell = '💸'  # Золото было справа
                
                multiplier = GOLD_MULTIPLIERS[level]
                win_for_level = format_number(int(game_data['bet'] * multiplier))
                message_text += f"|{left_cell}|{right_cell}| {win_for_level} VsCoin ({multiplier}x)\n"
            
            keyboard = [[InlineKeyboardButton("💥 Игра завершена", callback_data=f"gold_finished_{game_id}")]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                message_text,
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
        else:
            # УСПЕХ - нашли золото
            game_data['current_level'] += 1
            
            # Проверяем, пройдены ли все уровни
            if game_data['current_level'] >= 12:
                # ПОЛНАЯ ПОБЕДА - прошли все 12 уровней!
                final_multiplier = GOLD_MULTIPLIERS[11]
                win_amount = int(game_data['bet'] * final_multiplier)
                
                user_data['balance'] += win_amount
                user_data['games_played'] += 1
                user_data['wins'] += 1
                user_data['won_amount'] += win_amount
                game_data['game_state'] = 'won'
                
                # Обновляем данные
                user_data['active_game'] = None
                db.update_user(user.id, user_data)
                
                # ПОКАЗЫВАЕМ ПОЛНУЮ ТАБЛИЦУ ПРИ ПОЛНОЙ ПОБЕДЕ
                user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
                message_text = f"{user_link}\n🏆 Золото · ПОЛНАЯ ПОБЕДА!\n·····················\n💸 Ставка: {game_data['bet']} VsCoin\n💰 Выигрыш: {format_number(win_amount)} VsCoin (х4096!)\n⚜️ Пройдено: 12 из 12\n\n"
                
                # ПОЛНАЯ ТАБЛИЦА: показываем все 12 уровней с реальным расположением
                for level in range(11, -1, -1):
                    # Определяем что было на этом уровне
                    if game_data['mine_positions'][level] == 0:
                        # Петарда слева, золото справа
                        gold_left = False
                        gold_right = True
                    else:
                        # Петарда справа, золото слева
                        gold_left = True
                        gold_right = False
                    
                    # Игрок прошел ВСЕ уровни правильно
                    if gold_left:
                        # Золото было слева
                        left_cell = '💰'  # Игрок нашел золото слева
                        right_cell = '🧨'  # Петарда справа
                    else:
                        # Золото было справа
                        left_cell = '🧨'  # Петарда слева
                        right_cell = '💰'  # Игрок нашел золото справа
                    
                    multiplier = GOLD_MULTIPLIERS[level]
                    win_for_level = format_number(int(game_data['bet'] * multiplier))
                    message_text += f"|{left_cell}|{right_cell}| {win_for_level} VsCoin ({multiplier}x)\n"
                
                keyboard = [[InlineKeyboardButton("🏆 Игра завершена", callback_data=f"gold_finished_{game_id}")]]
                reply_markup = InlineKeyboardMarkup(keyboard)
                
                await query.edit_message_text(
                    message_text,
                    parse_mode=ParseMode.HTML,
                    reply_markup=reply_markup
                )
            else:
                # Продолжаем игру - обновляем поле (только пройденные уровни)
                user_data['active_game'] = game_data
                db.update_user(user.id, user_data)
                
                # Обновляем игру в context
                context.user_data[game_id] = game_data
                
                # Показываем обновленное поле (только в процессе игры)
                await show_gold_game(update, context, user, game_data, game_id)
    
    elif action == "finished":
        # Завершение игры
        if game_id in context.user_data:
            del context.user_data[game_id]
        
        if user_data.get('active_game'):
            user_data['active_game'] = None
            db.update_user(user.id, user_data)
        
        await query.answer("Игра завершена!")

# Обновите функцию show_gold_game (только для процесса игры):
async def show_gold_game(update: Update, context: ContextTypes.DEFAULT_TYPE, user, game_data, game_id=None):
    """Показать текущее состояние игры в золото (только в процессе)"""
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    # Текст сообщения
    if game_data['current_level'] == 0:
        status = "🟡 Золото · начни игру!"
        current_multiplier = 1
    else:
        current_multiplier = GOLD_MULTIPLIERS[game_data['current_level'] - 1]
        win_amount = int(game_data['bet'] * current_multiplier)
        status = f"⚜️ Золото · игра идёт.\n·····················\n💸 Ставка: {game_data['bet']} VsCoin\n💰 Выигрыш: х{current_multiplier} / {format_number(win_amount)} VsCoin"
    
    message_text = f"{user_link}\n{status}\n\n"
    
    # В ПРОЦЕССЕ ИГРЫ: показываем только пройденные уровни + текущий
    for level in range(11, -1, -1):  # от 11 до 0
        if level < game_data['current_level']:
            # Пройденные уровни - показываем выбор игрока
            if game_data['selected_cells'][level] == 'left':
                left_cell = '💰'  # Игрок выбрал лево и нашел золото
                right_cell = '❓'
            else:
                left_cell = '❓'
                right_cell = '💰'  # Игрок выбрал право и нашел золото
        elif level == game_data['current_level']:
            # Текущий уровень
            left_cell = '❓'
            right_cell = '❓'
        else:
            # Будущие уровни
            left_cell = '❓'
            right_cell = '❓'
        
        multiplier = GOLD_MULTIPLIERS[level]
        win_for_level = format_number(int(game_data['bet'] * multiplier))
        message_text += f"|{left_cell}|{right_cell}| {win_for_level} VsCoin ({multiplier}x)\n"
    
    # Создаем клавиатуру
    keyboard = []
    
    if game_data['game_state'] == 'playing':
        # Кнопки для выбора
        row1 = []
        row2 = []
        
        if game_data['current_level'] < 12:
            row1.append(InlineKeyboardButton("⬅️ Лево", callback_data=f"gold_left_{game_id}"))
            row1.append(InlineKeyboardButton("➡️ Право", callback_data=f"gold_right_{game_id}"))
        
        if row1:
            keyboard.append(row1)
        
        if game_data['current_level'] > 0:
            current_multiplier = GOLD_MULTIPLIERS[game_data['current_level'] - 1]
            win_amount = int(game_data['bet'] * current_multiplier)
            row2.append(InlineKeyboardButton(f"💰 Забрать {format_number(win_amount)} VsCoin", callback_data=f"gold_cashout_{game_id}"))
        
        if row2:
            keyboard.append(row2)
        
        keyboard.append([InlineKeyboardButton("❌ Отменить", callback_data=f"gold_cancel_{game_id}")])
    
    elif game_data['game_state'] == 'won':
        keyboard.append([InlineKeyboardButton("✅ Игра завершена", callback_data=f"gold_finished_{game_id}")])
    elif game_data['game_state'] == 'lost':
        keyboard.append([InlineKeyboardButton("💥 Игра завершена", callback_data=f"gold_finished_{game_id}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    if update.callback_query:
        await update.callback_query.edit_message_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
    else:
        message = await update.message.reply_text(
            message_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        if game_id and game_id in context.user_data:
            context.user_data[game_id]['message_id'] = message.message_id

# ==================== ИГРА АЛМАЗЫ (ПОЛНАЯ ВЕРСИЯ) ====================

# ==================== ИГРА АЛМАЗЫ (ИСПРАВЛЕННАЯ ВЕРСИЯ) ====================

# ==================== ИГРА АЛМАЗЫ (ИСПРАВЛЕННЫЙ ФОРМАТ CALLBACK) ====================

# Коэффициенты для Алмазов
PYRAMID_MULTIPLIERS = {
    1: [1.0, 1.46, 2.18, 3.27, 4.91, 7.37, 11.05, 16.57, 24.86, 37.29, 55.94, 83.91, 125.87, 188.8, 283.2, 424.8, 637.2],
    2: [1.0, 2.18, 4.91, 11.05, 24.86, 55.94, 125.87, 283.2, 637.2, 1433.7, 3225.8, 7258.0, 16330.5, 36743.6, 82673.1, 186000.0, 418500.0]
}

def create_pyramid_keyboard(game_data, show_mine=False, mine_cell=None):
    """Создает клавиатуру пирамиды (растет снизу вверх)"""
    keyboard = []
    
    # ВЕРХУШКА: текущий этаж для выбора
    if game_data.get('game_active', True) and game_data['current_floor'] < 16:
        current_row = [
            InlineKeyboardButton("1️⃣", callback_data=f"pyramid_choice_{game_data['game_key']}_0"),
            InlineKeyboardButton("2️⃣", callback_data=f"pyramid_choice_{game_data['game_key']}_1"),
            InlineKeyboardButton("3️⃣", callback_data=f"pyramid_choice_{game_data['game_key']}_2")
        ]
        keyboard.append(current_row)
    
    # СЕРЕДИНА: пройденные этажи (снизу вверх)
    for floor in range(game_data['current_floor']-1, -1, -1):
        row = []
        if floor < len(game_data['selected_cells']):
            selected_cell = game_data['selected_cells'][floor]
            # Проверяем, это этаж где произошел проигрыш?
            is_mine_floor = (show_mine and floor == game_data['current_floor']-1)
            
            for col in range(3):
                if is_mine_floor and col == mine_cell:
                    # Это место где взорвалась петарда
                    row.append(InlineKeyboardButton("💥", callback_data="pyramid_passed"))
                elif col == selected_cell:
                    # Это выбранная безопасная ячейка
                    row.append(InlineKeyboardButton("💎", callback_data="pyramid_passed"))
                elif col in game_data['mines_positions'][floor] and (show_mine or not game_data.get('game_active', True)):
                    # Это петарда (показываем если проиграли или игра завершена)
                    row.append(InlineKeyboardButton("🧨", callback_data="pyramid_passed"))
                else:
                    # Неоткрытая ячейка
                    row.append(InlineKeyboardButton("❓", callback_data="pyramid_passed"))
        else:
            row = [
                InlineKeyboardButton("❓", callback_data="pyramid_passed"),
                InlineKeyboardButton("❓", callback_data="pyramid_passed"),
                InlineKeyboardButton("❓", callback_data="pyramid_passed")
            ]
        keyboard.append(row)
    
    # НИЗ: кнопки действий
    if game_data.get('game_active', True):
        if game_data['current_floor'] > 0:
            # Кнопка ЗАБРАТЬ (ниже клавиатуры)
            next_multiplier = game_data['multipliers'][game_data['current_floor']]
            next_win = int(game_data['bet'] * next_multiplier)
            keyboard.append([InlineKeyboardButton(f"💰 Забрать {format_number(next_win)} Vscoin", callback_data=f"pyramid_cashout_{game_data['game_key']}")])
        else:
            # Кнопка ОТМЕНА (ниже клавиатуры)
            keyboard.append([InlineKeyboardButton("❌ Отмена", callback_data=f"pyramid_cancel_{game_data['game_key']}")])
    else:
        # Игра завершена
        keyboard.append([InlineKeyboardButton("✅ Игра завершена", callback_data="pyramid_finished")])
    
    return InlineKeyboardMarkup(keyboard)

async def pyramid_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Запуск игры Алмазы"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!")
        return
    
    if len(context.args) < 2:
        help_text = (
            "🏔 <b>АЛМАЗЫ</b>\n\n"
            "16 этажей по 3 ячейки. Избегай петард! 🧨\n"
            "Находи алмазы! 💎\n\n"
            "<b>Формат:</b> <code>/алмазы [ставка] [петарды 1-2]</code>\n\n"
            "<b>Пример:</b> <code>/алмазы 100 1</code>"
        )
        await update.message.reply_text(help_text, parse_mode=ParseMode.HTML)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        mines_count = int(context.args[1])
    except:
        await update.message.reply_text("❌ Неверный формат! Пример: /алмазы 100 1")
        return
    
    if mines_count < 1 or mines_count > 2:
        await update.message.reply_text("❌ Петарды: только 1 или 2!")
        return
    
    if bet <= 0:
        await update.message.reply_text("❌ Ставка должна быть > 0!")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text(f"❌ Недостаточно! Баланс: {format_number(user_data['balance'])} Vscoin")
        return
    
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Создаем поле с петардами
    mines_positions = []
    for floor in range(16):
        if mines_count == 1:
            mine_cell = random.randint(0, 2)
            mines_positions.append([mine_cell])
        else:
            mine_cells = random.sample([0, 1, 2], 2)
            mines_positions.append(mine_cells)
    
    multipliers = PYRAMID_MULTIPLIERS[mines_count]
    
    # Уникальный ключ игры (только цифры и буквы, без точек)
    game_key = f"pyramid_{user.id}_{int(time.time())}"
    
    game_data = {
        'type': 'pyramid',
        'bet': bet,
        'mines_count': mines_count,
        'mines_positions': mines_positions,
        'multipliers': multipliers,
        'current_floor': 0,
        'selected_cells': [],
        'game_key': game_key,
        'user_id': user.id,
        'game_active': True
    }
    
    context.user_data[game_key] = game_data
    
    # Клавиатура
    reply_markup = create_pyramid_keyboard(game_data)
    
    # Цепочка коэффициентов
    chain_text = "🪜 Следующий ряд:\n"
    for i in range(1, min(6, len(multipliers))):
        if i == 1:
            chain_text += f"1 • x{multipliers[i]:.2f}"
        else:
            chain_text += f" ➡️ {i} • x{multipliers[i]:.2f}"
    
    if len(multipliers) > 6:
        chain_text += " ➡️ ..."
    
    # Синий ник
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    await update.message.reply_text(
        f"{user_link}\n"
        f"🍀 Алмазы · начни игру!\n"
        f"·····················\n"
        f"🧨 Мин: {mines_count}\n"
        f"💸 Ставка: {format_number(bet)} Vscoin\n\n"
        f"{chain_text}",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def pyramid_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок Алмазов - УПРОЩЕННАЯ ВЕРСИЯ"""
    query = update.callback_query
    user = query.from_user
    
    # Получаем данные
    data = query.data
    print(f"DEBUG: Получен callback: {data}")  # Для отладки
    
    # Разбираем callback_data
    if data.startswith("pyramid_cancel_"):
        # ОТМЕНА ИГРЫ
        game_key = data.replace("pyramid_cancel_", "")
        print(f"DEBUG: Отмена игры, ключ: {game_key}")
        
        if game_key in context.user_data:
            game_data = context.user_data[game_key]
            
            # Проверяем владельца
            if game_data['user_id'] != user.id:
                await query.answer("❌ Это не ваша игра")
                return
            
            # Возвращаем деньги
            user_data = db.get_user(user.id)
            user_data['balance'] += game_data['bet']
            db.update_user(user.id, user_data)
            
            # Удаляем игру
            del context.user_data[game_key]
            
            await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
        else:
            await query.answer("❌ Игра уже завершена")
        
        await query.answer()
        return
    
    elif data.startswith("pyramid_cashout_"):
        # ЗАБРАТЬ ВЫИГРЫШ
        game_key = data.replace("pyramid_cashout_", "")
        print(f"DEBUG: Забрать выигрыш, ключ: {game_key}")
        
        if game_key not in context.user_data:
            await query.answer("❌ Игра не найдена")
            return
        
        game_data = context.user_data[game_key]
        
        # Проверяем владельца
        if game_data['user_id'] != user.id:
            await query.answer("❌ Это не ваша игра")
            return
        
        if game_data['current_floor'] == 0:
            await query.answer("❌ Сначала сделайте ход!")
            return
        
        user_data = db.get_user(user.id)
        
        # Вычисляем выигрыш
        current_multiplier = game_data['multipliers'][game_data['current_floor']]
        win_amount = int(game_data['bet'] * current_multiplier)
        profit = win_amount - game_data['bet']
        
        # Начисляем
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += profit
        db.update_user(user.id, user_data)
        
        game_data['game_active'] = False
        
        # Финальная клавиатура
        reply_markup = create_pyramid_keyboard(game_data)
        
        user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
        
        await query.edit_message_text(
            f"{user_link}\n"
            f"🎉 Алмазы · Победа! ✅\n"
            f"·····················\n"
            f"🧨 Мин: {game_data['mines_count']}\n"
            f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
            f"🪜 Пройдено: {game_data['current_floor']} из 16\n"
            f"💰 Выигрыш: х{current_multiplier:.2f} / {format_number(win_amount)} Vscoin",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        
        del context.user_data[game_key]
        await query.answer()
        return
    
    elif data.startswith("pyramid_choice_"):
        # ВЫБОР ЯЧЕЙКИ
        try:
            # Формат: pyramid_choice_GAMEKEY_CELLINDEX
            parts = data.split('_')
            if len(parts) < 3:
                await query.answer("❌ Ошибка в данных")
                return
            
            # game_key = parts[2] если parts = ["pyramid", "choice", "GAMEKEY", "CELLINDEX"]
            # Но лучше взять все после "pyramid_choice_"
            full_data = data.replace("pyramid_choice_", "")
            print(f"DEBUG: Выбор ячейки, данные: {full_data}")
            
            # Разделяем на ключ и индекс ячейки
            split_index = full_data.rfind('_')
            if split_index == -1:
                await query.answer("❌ Ошибка в данных")
                return
            
            game_key = full_data[:split_index]
            cell_index_str = full_data[split_index + 1:]
            
            print(f"DEBUG: Ключ игры: {game_key}, ячейка: {cell_index_str}")
            
            cell_index = int(cell_index_str)
            
            if game_key not in context.user_data:
                await query.answer("❌ Игра не найдена")
                return
            
            game_data = context.user_data[game_key]
            
            # Проверяем владельца
            if game_data['user_id'] != user.id:
                await query.answer("❌ Это не ваша игра")
                return
            
            current_floor = game_data['current_floor']
            user_data = db.get_user(user.id)
            
            # ПРОВЕРКА НА ПЕТАРДУ
            if cell_index in game_data['mines_positions'][current_floor]:
                # ПРОИГРЫШ
                user_data['games_played'] += 1
                user_data['losses'] += 1
                user_data['lost_amount'] += game_data['bet']
                db.update_user(user.id, user_data)
                
                game_data['game_active'] = False
                game_data['selected_cells'].append(cell_index)  # Добавляем выбранную ячейку
                game_data['current_floor'] += 1  # Увеличиваем счетчик этажей
                
                # Множитель который мог бы получить
                could_have_multiplier = game_data['multipliers'][current_floor + 1] if current_floor < len(game_data['multipliers']) - 1 else game_data['multipliers'][-1]
                could_have_win = int(game_data['bet'] * could_have_multiplier)
                
                # Финальная клавиатура с местом проигрыша
                reply_markup = create_pyramid_keyboard(game_data, show_mine=True, mine_cell=cell_index)
                
                user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
                
                await query.edit_message_text(
                    f"{user_link}\n"
                    f"💥 Алмазы · Проигрыш!\n"
                    f"·····················\n"
                    f"🧨 Мин: {game_data['mines_count']}\n"
                    f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
                    f"🪜 Пройдено: {current_floor} из 16\n"
                    f"✔️ Мог забрать: х{could_have_multiplier:.2f} / {format_number(could_have_win)} Vscoin",
                    parse_mode=ParseMode.HTML,
                    reply_markup=reply_markup
                )
                
                # Удаляем игру через 30 секунд
                await asyncio.sleep(30)
                if game_key in context.user_data:
                    del context.user_data[game_key]
                
                await query.answer()
                return
            
            # УСПЕШНЫЙ ВЫБОР
            game_data['selected_cells'].append(cell_index)
            game_data['current_floor'] += 1
            
            # Проверяем вершину
            if game_data['current_floor'] >= 16:
                # ДОСТИГЛИ ВЕРШИНЫ
                win_multiplier = game_data['multipliers'][-1]
                win_amount = int(game_data['bet'] * win_multiplier)
                profit = win_amount - game_data['bet']
                
                user_data['balance'] += win_amount
                user_data['games_played'] += 1
                user_data['wins'] += 1
                user_data['won_amount'] += profit
                db.update_user(user.id, user_data)
                
                game_data['game_active'] = False
                
                reply_markup = create_pyramid_keyboard(game_data)
                
                user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
                
                await query.edit_message_text(
                    f"{user_link}\n"
                    f"🏆 Алмазы · Достигнута вершина! ✅\n"
                    f"·····················\n"
                    f"🧨 Мин: {game_data['mines_count']}\n"
                    f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
                    f"🪜 Пройдено: 16 из 16 (ВЕРШИНА!)\n"
                    f"💰 Выигрыш: х{win_multiplier:.2f} / {format_number(win_amount)} Vscoin",
                    parse_mode=ParseMode.HTML,
                    reply_markup=reply_markup
                )
                
                del context.user_data[game_key]
                await query.answer()
                return
            
            # Сохраняем обновленную игру
            context.user_data[game_key] = game_data
            
            # Цепочка коэффициентов
            chain_text = "🪜 Следующий ряд:\n"
            start_idx = game_data['current_floor']
            display_count = min(6, len(game_data['multipliers']) - start_idx)
            
            for i in range(start_idx, start_idx + display_count):
                if i == start_idx:
                    chain_text += f"{i} • x{game_data['multipliers'][i]:.2f}"
                else:
                    chain_text += f" ➡️ {i} • x{game_data['multipliers'][i]:.2f}"
            
            if len(game_data['multipliers']) - start_idx > display_count:
                chain_text += " ➡️ ..."
            
            # Обновленная клавиатура
            reply_markup = create_pyramid_keyboard(game_data)
            
            # Текущий выигрыш
            next_multiplier = game_data['multipliers'][game_data['current_floor']]
            next_win = int(game_data['bet'] * next_multiplier)
            
            user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
            
            await query.edit_message_text(
                f"{user_link}\n"
                f"💠 Алмазы · игра идёт!\n"
                f"·····················\n"
                f"🧨 Мин: {game_data['mines_count']}\n"
                f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
                f"📊 Выигрыш: х{next_multiplier:.2f} / {format_number(next_win)} Vscoin\n\n"
                f"{chain_text}",
                parse_mode=ParseMode.HTML,
                reply_markup=reply_markup
            )
            
            await query.answer()
            
        except Exception as e:
            print(f"DEBUG: Ошибка при обработке выбора: {e}")
            await query.answer("❌ Ошибка при обработке хода")
            return
    
    elif data == "pyramid_passed" or data == "pyramid_finished":
        await query.answer("Это пройденный этаж")
        return
    
    else:
        await query.answer("❌ Неизвестная команда")


# Вызовите в main():
# setup_pyramid_handlers(application)
# Обновленные коэффициенты для башни
TOWER_MULTIPLIERS = {
    1: [1.21, 1.52, 1.89, 2.37, 2.96, 3.70, 4.63, 5.78, 7.23],
    2: [1.62, 2.69, 4.49, 7.48, 12.47, 20.79, 34.65, 57.75, 96.25],
    3: [2.42, 6.06, 15.16, 37.89, 94.73, 236.82, 592.04, 900.0, 1233.0],
    4: [4.85, 24.25, 121.25, 606.25, 3031.25, 3565.0, 4212.0, 5125.0, 6000.0]
}

async def tower_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("Вы забанены и не можете играть")
        return
    
    if len(context.args) < 2:
        help_text = (
            "🛕 <b>ИГРА В БАШНЮ</b>\n\n"
            "📝 <b>Формат:</b> <code>/башня [ставка] [мин 1-4]</code>\n\n"
            "🎯 <b>Примеры:</b>\n"
            "<code>/башня 100 1</code>\n"
            "<code>/башня 500 2</code>\n\n"
            "💰 <b>Коэффициенты:</b>\n"
            "1 мина: 1 • x1.21 → 2 • x1.52 → 3 • x1.89 → 4 • x2.37 → 5 • x2.96 → 6 • x3.70 → 7 • x4.63 → 8 • x5.78 → 9 • x7.23\n"
            "2 мины: 1 • x1.62 → 2 • x2.69 → 3 • x4.49 → 4 • x7.48 → 5 • x12.47 → 6 • x20.79 → 7 • x34.65 → 8 • x57.75 → 9 • x96.25\n"
            "3 мины: 1 • x2.42 → 2 • x6.06 → 3 • x15.16 → 4 • x37.89 → 5 • x94.73 → 6 • x236.82 → 7 • x592.04 → 8 • x900 → 9 • x1233\n"
            "4 мины: 1 • x4.85 → 2 • x24.25 → 3 • x121.25 → 4 • x606.25 → 5 • x3031.25 → 6 • x3565 → 7 • x4212 → 8 • x5125 → 9 • x6000\n\n"
            "🏗 <b>Максимум этажей:</b> 9"
        )
        await update.message.reply_text(help_text, parse_mode=ParseMode.HTML)
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        mines_count = int(context.args[1])
    except:
        await update.message.reply_text("❌ Неверный формат! Пример: /башня 100 1")
        return
    
    if mines_count < 1 or mines_count > 4:
        await update.message.reply_text("❌ Количество мин: 1-4!")
        return
    
    if bet <= 0:
        await update.message.reply_text("❌ Ставка должна быть > 0!")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text(f"❌ Недостаточно! Баланс: {format_number(user_data['balance'])} Vscoin")
        return
    
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Создаем 9 этажей (этаж 1-9)
    mine_positions = []
    for floor in range(1, 10):
        floor_mines = random.sample(range(5), mines_count)
        mine_positions.append(floor_mines)
    
    # Получаем коэффициенты для выбранного количества мин
    multipliers = TOWER_MULTIPLIERS.get(mines_count, TOWER_MULTIPLIERS[1])
    
    # Начинаем с множителя 1x, но показываем что на 1 этаже будет 1.21x
    game_data = {
        'type': 'tower',
        'bet': bet,
        'mines_count': mines_count,
        'mine_positions': mine_positions,
        'multipliers': multipliers,
        'current_floor': 1,  # Текущий этаж 1
        'next_multiplier': multipliers[0],  # Коэффициент за успешный проход 1 этажа
        'current_multiplier': 1.00,  # Текущий множитель (пока 1x)
        'selected_cells': [],
    }
    
    user_data['active_game'] = game_data
    db.update_user(user.id, user_data)
    
    # ПЕРВЫЙ этаж - сразу активный для выбора
    keyboard = [
        [InlineKeyboardButton("❔", callback_data="tower_1_0"),
         InlineKeyboardButton("❔", callback_data="tower_1_1"),
         InlineKeyboardButton("❔", callback_data="tower_1_2"),
         InlineKeyboardButton("❔", callback_data="tower_1_3"),
         InlineKeyboardButton("❔", callback_data="tower_1_4")],
        [InlineKeyboardButton(f"💰 Забрать {format_number(bet)} Vscoin", callback_data="tower_cashout"),
         InlineKeyboardButton("❌ Отменить", callback_data="tower_cancel")]
    ]
    
    # Цепочка для первого этажа - показываем что на 1 этаже будет 1.21x
    chain_text = "🔝 Следующие уровни:\n"
    chain_text += f"1 • x{multipliers[0]:.2f}"
    for i in range(1, min(5, len(multipliers))):
        chain_text += f" → {i+1} • x{multipliers[i]:.2f}"
    if len(multipliers) > 5:
        chain_text += " → ..."
    
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"{user_link}\n"
        f"🏗️ Башня · этаж 1 из 9\n"
        f"·····················\n"
        f"💣 Мин: {mines_count}\n"
        f"💸 Ставка: {format_number(bet)} Vscoin\n"
        f"📈 Текущий множитель: x{game_data['current_multiplier']:.2f}\n"
        f"📈 Множитель за этаж: x{game_data['next_multiplier']:.2f}\n"
        f"💰 Текущий выигрыш: {format_number(bet)} Vscoin\n\n"
        f"{chain_text}",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def tower_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('active_game') or user_data['active_game'].get('type') != 'tower':
        await query.answer("У вас нет активной игры")
        return
    
    game_data = user_data['active_game']
    
    if query.data == "tower_cancel":
        user_data['balance'] += game_data['bet']
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
        return
    
    if query.data == "tower_cashout":
        win_amount = int(game_data['bet'] * game_data['current_multiplier'])
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        # Показываем пройденные этажи
        keyboard = []
        for floor in range(len(game_data['selected_cells']), 0, -1):
            floor_index = floor - 1
            row = []
            for cell in range(5):
                if cell == game_data['selected_cells'][floor_index]:
                    row.append(InlineKeyboardButton("💎", callback_data="no_action"))
                else:
                    row.append(InlineKeyboardButton("❔", callback_data="no_action"))
            keyboard.append(row)
        
        keyboard.append([InlineKeyboardButton("✅ Вы забрали выигрыш", callback_data="no_action")])
        
        await query.edit_message_text(
            f"🎉 Вы забрали выигрыш!\n"
            f"💰 Выигрыш: {format_number(win_amount)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return
    
    # Обработка нажатия на ячейку
    parts = query.data.split('_')
    floor = int(parts[1])  # Этаж (1-9)
    cell = int(parts[2])   # Ячейка (0-4)
    
    # Проверяем, что игрок нажимает на текущем этаже
    if floor != game_data['current_floor']:
        await query.answer(f"Выбери на этаже {game_data['current_floor']}!")
        return
    
    floor_index = floor - 1
    
    # Проверяем, попал ли на мину
    if cell in game_data['mine_positions'][floor_index]:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += game_data['bet']
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        # Показываем пройденные этажи и текущий с миной
        keyboard = []
        
        # Пройденные этажи
        for f in range(len(game_data['selected_cells']), 0, -1):
            f_index = f - 1
            row = []
            for c in range(5):
                if c == game_data['selected_cells'][f_index]:
                    row.append(InlineKeyboardButton("💎", callback_data="no_action"))
                else:
                    row.append(InlineKeyboardButton("❔", callback_data="no_action"))
            keyboard.append(row)
        
        # Текущий этаж с миной
        row = []
        for c in range(5):
            if c == cell:
                row.append(InlineKeyboardButton("💥", callback_data="no_action"))
            elif c in game_data['mine_positions'][floor_index]:
                row.append(InlineKeyboardButton("💣", callback_data="no_action"))
            else:
                row.append(InlineKeyboardButton("❔", callback_data="no_action"))
        keyboard.append(row)
        
        keyboard.append([InlineKeyboardButton("💥 Вы проиграли", callback_data="no_action")])
        
        await query.edit_message_text(
            f"💥 Вы попали на мину на этаже {floor}!\n"
            f"💸 Проигрыш: {format_number(game_data['bet'])} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return
    
    # УСПЕШНЫЙ ВЫБОР - нет мины
    game_data['selected_cells'].append(cell)
    
    # Устанавливаем текущий множитель как множитель за ПРОЙДЕННЫЙ этаж
    game_data['current_multiplier'] = game_data['next_multiplier']
    
    # Увеличиваем этаж
    game_data['current_floor'] += 1
    
    # Проверяем, достигли ли максимального этажа (9)
    if game_data['current_floor'] > 9:
        win_amount = int(game_data['bet'] * game_data['current_multiplier'])
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        user_data['active_game'] = None
        db.update_user(user.id, user_data)
        
        # Показываем все 9 этажей
        keyboard = []
        for floor_num in range(9, 0, -1):
            f_index = floor_num - 1
            row = []
            for cell_num in range(5):
                if floor_num <= len(game_data['selected_cells']) and cell_num == game_data['selected_cells'][f_index]:
                    row.append(InlineKeyboardButton("💎", callback_data="no_action"))
                else:
                    row.append(InlineKeyboardButton("❔", callback_data="no_action"))
            keyboard.append(row)
        
        keyboard.append([InlineKeyboardButton("🎉 Победа!", callback_data="no_action")])
        
        await query.edit_message_text(
            f"🎉 Поздравляем! Вы прошли всю башню!\n"
            f"💰 Выигрыш: {format_number(win_amount)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return
    
    # Устанавливаем следующий множитель (для следующего этажа)
    next_index = game_data['current_floor'] - 1
    game_data['next_multiplier'] = game_data['multipliers'][next_index]
    
    # Сохраняем обновленную игру
    user_data['active_game'] = game_data
    db.update_user(user.id, user_data)
    
    # СОЗДАЕМ НОВУЮ КЛАВИАТУРУ для следующего этажа
    keyboard = []
    
    # Показываем пройденные этажи
    for floor_num in range(len(game_data['selected_cells']), 0, -1):
        f_index = floor_num - 1
        row = []
        for i in range(5):
            if i == game_data['selected_cells'][f_index]:
                row.append(InlineKeyboardButton("💎", callback_data="no_action"))
            else:
                row.append(InlineKeyboardButton("❔", callback_data="no_action"))
        keyboard.append(row)
    
    # Следующий активный этаж
    next_floor = game_data['current_floor']
    current_row = []
    for i in range(5):
        current_row.append(InlineKeyboardButton("❔", callback_data=f"tower_{next_floor}_{i}"))
    keyboard.append(current_row)
    
    # Кнопки действия
    win_amount = int(game_data['bet'] * game_data['current_multiplier'])
    keyboard.append([
        InlineKeyboardButton(f"💰 Забрать {format_number(win_amount)} Vscoin", callback_data="tower_cashout"),
        InlineKeyboardButton("❌ Отменить", callback_data="tower_cancel")
    ])
    
    # Формируем текст цепочки для следующего этажа
    chain_text = "🔝 Следующие уровни:\n"
    start_floor = next_floor
    start_index = start_floor - 1
    
    chain_text += f"{start_floor} • x{game_data['multipliers'][start_index]:.2f}"
    for i in range(start_index + 1, min(start_index + 5, 9)):
        chain_text += f" → {i+1} • x{game_data['multipliers'][i]:.2f}"
    if start_index + 5 < 9:
        chain_text += " → ..."
    
    user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
    
    await query.edit_message_text(
        f"{user_link}\n"
        f"🏗️ Башня · этаж {next_floor} из 9\n"
        f"·····················\n"
        f"💣 Мин: {game_data['mines_count']}\n"
        f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
        f"📈 Текущий множитель: x{game_data['current_multiplier']:.2f}\n"
        f"📈 Множитель за этаж: x{game_data['next_multiplier']:.2f}\n"
        f"💰 Текущий выигрыш: {format_number(win_amount)} Vscoin\n\n"
        f"{chain_text}",
        parse_mode=ParseMode.HTML,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )
    
    await query.answer()

async def tower_finished_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer("Игра уже завершена!")

# ==================== ИГРА HILO ====================

async def hilo_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Запуск игры HiLo"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    original_msg_id = update.message.message_id

    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!", reply_to_message_id=original_msg_id)
        return
    
    if len(context.args) < 1:
        help_text = (
            "🍀 <b>HiLo</b>\n"
            "Ставка: /хило [сумма]\n"
            "Угадай, следующая карта будет выше или ниже!"
        )
        await update.message.reply_text(help_text, parse_mode=ParseMode.HTML, reply_to_message_id=original_msg_id)
        return

    try:
        bet = parse_bet(context.args[0], user_data['balance'])
        if bet <= 0 or user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Ошибка! Доступно: {format_number(user_data['balance'])}", reply_to_message_id=original_msg_id)
            return
    except:
        await update.message.reply_text("❌ Используй: /хило 100", reply_to_message_id=original_msg_id)
        return

    # Создаём колоду
    suits = ['♠️', '♥️', '♦️', '♣️']
    ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
    deck = [f"{rank}{suit}" for suit in suits for rank in ranks]
    random.shuffle(deck)
    
    # Первая карта
    first_card = random.choice(deck)
    deck.remove(first_card)
    
    # Сохраняем игру
    game_key = f'hilo_{user.id}_{original_msg_id}'
    context.user_data[game_key] = {
        'bet': bet,
        'deck': deck,
        'current_card': first_card,
        'history': [],
        'refresh_used': 0,
        'max_refresh': 3,
        'multiplier': 1.0,
        'original_msg_id': original_msg_id,
        'user_id': user.id,
        'cards_guessed': 0,
        'game_active': True
    }

    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)

    # Показываем начальный экран
    keyboard = [
        [InlineKeyboardButton("🎮 Начать игру", callback_data=f"hilo_start_{game_key}")],
        [InlineKeyboardButton("❌ Отменить", callback_data=f"hilo_cancel_{game_key}")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"{user.full_name}\n"
        f"🍀 HiLo · начни игру!\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(bet)} Vscoin\n",
        reply_markup=reply_markup,
        reply_to_message_id=original_msg_id
    )

def hilo_calculate_probabilities(game_data):
    """Рассчитать вероятности для текущей карты (с урезанными коэффициентами)"""
    current_card = game_data['current_card']
    deck = game_data['deck']
    
    # Определяем значение текущей карты
    rank_order = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
    current_rank = current_card[:-2] if current_card[:-2] in rank_order else current_card[:-1]
    current_index = rank_order.index(current_rank)
    
    # Считаем карты выше и ниже
    higher_cards = 0
    lower_cards = 0
    same_cards = 0  # Карты такого же достоинства
    
    for card in deck:
        rank = card[:-2] if card[:-2] in rank_order else card[:-1]
        card_index = rank_order.index(rank)
        
        if card_index > current_index:
            higher_cards += 1
        elif card_index < current_index:
            lower_cards += 1
        else:
            same_cards += 1
    
    total_cards = len(deck)
    
    if total_cards == 0:
        return 0.5, 0.5
    
    # Реальные вероятности
    real_higher_prob = higher_cards / total_cards
    real_lower_prob = lower_cards / total_cards
    same_prob = same_cards / total_cards
    
    # УМЕНЬШАЕМ КОЭФФИЦИЕНТЫ (увеличиваем вероятность выигрыша для казино)
    # Если "выше" должно выпадать чаще (особенно для низких карт), 
    # то увеличиваем вероятность "выше" и уменьшаем "ниже"
    
    # Для низких карт (2-7) делаем "выше" более вероятным
    if current_index <= 5:  # Карты 2-7
        # Делаем "выше" в 3 раза вероятнее реального
        higher_prob = min(0.9, real_higher_prob * 3)
        # Делаем "ниже" в 2 раза менее вероятным
        lower_prob = max(0.05, real_lower_prob / 2)
    
    # Для средних карт (8-10)
    elif current_index <= 8:  # Карты 8-10
        # Более сбалансированные шансы
        higher_prob = min(0.8, real_higher_prob * 2)
        lower_prob = max(0.1, real_lower_prob / 1.5)
    
    # Для высоких карт (J-A) делаем "ниже" более вероятным
    else:  # Карты J, Q, K, A
        # Делаем "ниже" в 3 раза вероятнее реального
        lower_prob = min(0.9, real_lower_prob * 3)
        # Делаем "выше" в 2 раза менее вероятным
        higher_prob = max(0.05, real_higher_prob / 2)
    
    # Учитываем одинаковые карты
    if same_cards > 0:
        # Распределяем шансы одинаковых карт между выше/ниже
        higher_prob += same_prob * (higher_prob / (higher_prob + lower_prob) if (higher_prob + lower_prob) > 0 else 0.5)
        lower_prob += same_prob * (lower_prob / (higher_prob + lower_prob) if (higher_prob + lower_prob) > 0 else 0.5)
    
    # Гарантируем минимальные вероятности
    higher_prob = max(0.05, higher_prob)
    lower_prob = max(0.05, lower_prob)
    
    # Нормализуем
    total = higher_prob + lower_prob
    higher_prob = higher_prob / total
    lower_prob = lower_prob / total
    
    return higher_prob, lower_prob

async def hilo_play_round(query, context, game_data, game_key, user, user_data):
    """Показать текущий раунд"""
    current_card = game_data['current_card']
    history = game_data['history']
    
    # Рассчитываем вероятности
    higher_prob, lower_prob = hilo_calculate_probabilities(game_data)
    
    # УМЕНЬШАЕМ КОЭФФИЦИЕНТЫ В 2 РАЗА
    if higher_prob > 0:
        higher_multiplier = round((1.0 / higher_prob) / 2, 2)
    else:
        higher_multiplier = 1.0
        
    if lower_prob > 0:
        lower_multiplier = round((1.0 / lower_prob) / 2, 2)
    else:
        lower_multiplier = 1.0
    
    # Форматируем проценты
    higher_percent = int(higher_prob * 100)
    lower_percent = int(lower_prob * 100)
    
    # Создаем клавиатуру
    keyboard = []
    
    # Кнопка Обновить карту
    if game_data['refresh_used'] < game_data['max_refresh']:
        refresh_text = f"🔄 Обновить карту ({game_data['refresh_used']}/{game_data['max_refresh']})"
        keyboard.append([InlineKeyboardButton(refresh_text, callback_data=f"hilo_refresh_{game_key}")])
    
    # Кнопки Выше/Ниже
    higher_text = f"⬆️ {higher_percent}% (x{higher_multiplier})"
    lower_text = f"⬇️ {lower_percent}% (x{lower_multiplier})"
    keyboard.append([
        InlineKeyboardButton(higher_text, callback_data=f"hilo_higher_{game_key}"),
        InlineKeyboardButton(lower_text, callback_data=f"hilo_lower_{game_key}")
    ])
    
    # Кнопка Забрать
    if game_data['cards_guessed'] > 0:
        cashout_amount = int(game_data['bet'] * game_data['multiplier'])
        keyboard.append([InlineKeyboardButton(f"💰 Забрать {format_number(cashout_amount)} Vscoin", callback_data=f"hilo_cashout_{game_key}")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    # Формируем текст истории
    history_text = ""
    if history:
        history_text = "📥 Предыдущие:\n"
        for mult, card in reversed(history[-3:]):
            history_text += f"x{mult} • {card}\n"
    
    await query.edit_message_text(
        f"{user.full_name}\n"
        f"↕️ HiLo · игра идёт.\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
        f"📈 Множитель: x{game_data['multiplier']:.2f}\n\n"
        f"🃏 Карта: {current_card}\n\n"
        f"🫵 Какая будет след. карта?\n"
        f"{history_text}",
        reply_markup=reply_markup
    )

async def hilo_process_choice(query, context, game_data, game_key, user, user_data, choice):
    """Обработка выбора выше/ниже"""
    current_card = game_data['current_card']
    deck = game_data['deck']
    
    if not deck:
        await query.edit_message_text("❌ В колоде не осталось карт!")
        return
    
    # Определяем значения карт
    rank_order = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
    current_rank = current_card[:-2] if current_card[:-2] in rank_order else current_card[:-1]
    current_index = rank_order.index(current_rank)
    
    # Используем вероятности из расчета (уже измененные)
    higher_prob, lower_prob = hilo_calculate_probabilities(game_data)
    
    if choice == "higher":
        win_chance = higher_prob  # Используем расчетную вероятность
    else:  # choice == "lower"
        win_chance = lower_prob   # Используем расчетную вероятность
    
    is_correct = False
    
    if random.random() < win_chance:
        # Игрок должен выиграть - ищем подходящую карту
        possible_cards = []
        for card in deck:
            rank = card[:-2] if card[:-2] in rank_order else card[:-1]
            card_index = rank_order.index(rank)
            
            if (choice == "higher" and card_index > current_index) or \
               (choice == "lower" and card_index < current_index):
                possible_cards.append(card)
        
        if possible_cards:
            next_card = random.choice(possible_cards)
            is_correct = True
        else:
            # Если не нашли подходящую карту, берем любую
            next_card = random.choice(deck)
            is_correct = False
    else:
        # Игрок должен проиграть - намеренно выбираем неправильную карту
        possible_cards = []
        for card in deck:
            rank = card[:-2] if card[:-2] in rank_order else card[:-1]
            card_index = rank_order.index(rank)
            
            if (choice == "higher" and card_index <= current_index) or \
               (choice == "lower" and card_index >= current_index):
                possible_cards.append(card)
        
        if possible_cards:
            next_card = random.choice(possible_cards)
        else:
            next_card = random.choice(deck)
        is_correct = False
    
    deck.remove(next_card)
    
    if is_correct:
        # Игрок угадал
        game_data['cards_guessed'] += 1
        
        # Рассчитываем новый множитель (УМЕНЬШЕННЫЙ В 2 РАЗА)
        higher_prob, lower_prob = hilo_calculate_probabilities(game_data)
        if choice == "higher":
            new_multiplier = round((1.0 / higher_prob if higher_prob > 0 else 1.0) / 2, 2)
        else:
            new_multiplier = round((1.0 / lower_prob if lower_prob > 0 else 1.0) / 2, 2)
        
        # Умножаем общий множитель
        game_data['multiplier'] *= new_multiplier
        game_data['multiplier'] = round(game_data['multiplier'], 2)
        
        # Добавляем в историю
        game_data['history'].append((new_multiplier, next_card))
        
        # Обновляем текущую карту
        game_data['current_card'] = next_card
        game_data['deck'] = deck
        
        # Сохраняем обновлённые данные
        context.user_data[game_key] = game_data
        
        # Продолжаем игру
        await hilo_play_round(query, context, game_data, game_key, user, user_data)
        
    else:
        # Игрок проиграл
        game_data['game_active'] = False
        
        # Форматируем историю
        history_text = ""
        if game_data['history']:
            history_text = "📥 Предыдущие:\n"
            for mult, card in game_data['history']:
                history_text += f"x{mult} • {card}\n"
        
        result_text = (
            f"{user.full_name}\n"
            f"💥 HiLo · Проигрыш!\n"
            f"·····················\n"
            f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
            f"🃏 Была: {current_card}\n"
            f"🎲 Выпало: {next_card}\n"
            f"🔢 Угадано карт: {game_data['cards_guessed']}\n"
        )
        
        if history_text:
            result_text += f"\n{history_text}"
        
        await query.edit_message_text(result_text)
        
        # Обновляем статистику
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += game_data['bet']
        db.update_user(user.id, user_data)
        
        # Очищаем данные игры
        del context.user_data[game_key]

async def hilo_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик всех callback HiLo"""
    query = update.callback_query
    await query.answer()
    
    data = query.data
    parts = data.split('_')
    action = parts[1]
    game_key = '_'.join(parts[2:])
    
    user = query.from_user
    user_data = db.get_user(user.id)
    
    # Получаем данные игры
    game_data = context.user_data.get(game_key)
    if not game_data:
        await query.edit_message_text("❌ Игра не найдена или завершена")
        return
    
    if game_data['user_id'] != user.id:
        await query.answer("❌ Это не ваша игра")
        return
    
    if action == "start":
        await hilo_play_round(query, context, game_data, game_key, user, user_data)
    
    elif action == "cancel":
        # Возвращаем ставку
        user_data['balance'] += game_data['bet']
        db.update_user(user.id, user_data)
        del context.user_data[game_key]
        await query.edit_message_text("❌ Игра отменена. Ставка возвращена.")
    
    elif action == "higher":
        await hilo_process_choice(query, context, game_data, game_key, user, user_data, "higher")
    
    elif action == "lower":
        await hilo_process_choice(query, context, game_data, game_key, user, user_data, "lower")
    
    elif action == "refresh":
        await hilo_refresh_card(query, context, game_data, game_key, user, user_data)
    
    elif action == "cashout":
        await hilo_cashout(query, context, game_data, game_key, user, user_data)

async def hilo_refresh_card(query, context, game_data, game_key, user, user_data):
    """Обновить текущую карту"""
    if game_data['refresh_used'] >= game_data['max_refresh']:
        await query.answer("❌ Лимит обновлений исчерпан")
        return
    
    deck = game_data['deck']
    if len(deck) < 2:
        await query.answer("❌ Недостаточно карт в колоде")
        return
    
    # Возвращаем текущую карту в колоду
    current_card = game_data['current_card']
    deck.append(current_card)
    
    # Выбираем новую карту
    new_card = random.choice(deck)
    deck.remove(new_card)
    
    # Обновляем данные
    game_data['current_card'] = new_card
    game_data['deck'] = deck
    game_data['refresh_used'] += 1
    
    # Уменьшаем множитель за обновление
    game_data['multiplier'] *= 0.9
    game_data['multiplier'] = round(game_data['multiplier'], 2)
    
    context.user_data[game_key] = game_data
    
    await query.answer(f"🔄 Карта обновлена: {new_card}")
    await hilo_play_round(query, context, game_data, game_key, user, user_data)

async def hilo_cashout(query, context, game_data, game_key, user, user_data):
    """Забрать выигрыш"""
    if not game_data['game_active']:
        await query.answer("❌ Игра уже завершена")
        return
    
    win_amount = int(game_data['bet'] * game_data['multiplier'])
    user_data['balance'] += win_amount
    
    # Обновляем статистику
    user_data['games_played'] += 1
    user_data['wins'] += 1
    user_data['won_amount'] += (win_amount - game_data['bet'])
    
    db.update_user(user.id, user_data)
    
    game_data['game_active'] = False
    
    # Форматируем историю
    history_text = ""
    if game_data['history']:
        history_text = "📥 Предыдущие:\n"
        for mult, card in game_data['history']:
            history_text += f"x{mult} • {card}\n"
    
    await query.edit_message_text(
        f"{user.full_name}\n"
        f"🔥 HiLo · Победа! ✅\n"
        f"·····················\n"
        f"💸 Ставка: {format_number(game_data['bet'])} Vscoin\n"
        f"💰 Выигрыш: x{game_data['multiplier']:.2f} / {format_number(win_amount)} Vscoin\n"
        f"🃏 Последняя карта: {game_data['current_card']}\n"
        f"🔢 Угадано карт: {game_data['cards_guessed']}\n"
        f"{history_text}"
    )
    
    # Очищаем данные игры
    del context.user_data[game_key]
async def chest_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if user_data.get('banned', False):
        await update.message.reply_text("Вы забанены и не можете играть")
        return
    
    if len(context.args) < 1:
        await update.message.reply_text("Использование: 'сундук [ставка]'")
        return
    
    try:
        bet = parse_bet(context.args[0], user_data['balance'])
    except:
        await update.message.reply_text("Неверный формат ставки")
        return
    
    if bet <= 0:
        await update.message.reply_text("Ставка должна быть положительной")
        return
    
    if user_data['balance'] < bet:
        await update.message.reply_text("Недостаточно средств")
        return
    
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    winning_key = random.randint(0, 2)
    
    game_data = {
        'type': 'chest',
        'bet': bet,
        'winning_key': winning_key,
        'multiplier': 3.5
    }
    
    user_data['active_game'] = game_data
    db.update_user(user.id, user_data)
    
    keyboard = [
        [InlineKeyboardButton("🗝️ Ключ 1", callback_data="chest_0"),
         InlineKeyboardButton("🗝️ Ключ 2", callback_data="chest_1"),
         InlineKeyboardButton("🗝️ Ключ 3", callback_data="chest_2")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🗝️ Игра в сундук\n\n"
        f"💰 Ставка: {format_number(bet)} Vscoin\n"
        f"🎯 Множитель: x{game_data['multiplier']}\n"
        f"💰 Потенциальный выигрыш: {format_number(int(bet * game_data['multiplier']))} Vscoin\n\n"
        f"Выберите ключ:",
        reply_markup=reply_markup
    )

async def chest_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('active_game') or user_data['active_game'].get('type') != 'chest':
        await query.answer("У вас нет активной игры")
        return
    
    game_data = user_data['active_game']
    
    selected_key = int(query.data.split('_')[1])
    
    if selected_key == game_data['winning_key']:
        win_amount = int(game_data['bet'] * game_data['multiplier'])
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += win_amount
        
        animation_msg = await query.message.reply_text("🔐 Открываем сундук...")
        await asyncio.sleep(2)
        
        await context.bot.delete_message(
            chat_id=query.message.chat_id, 
            message_id=animation_msg.message_id
        )
        
        await query.edit_message_text(
            f"🔐 {user.full_name}, Вы успешно отгадали ключ!\n\n"
            f"💰 Ваш выигрыш: {format_number(win_amount)} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    else:
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += game_data['bet']
        
        animation_msg = await query.message.reply_text("🔐 Ключ не подходит...")
        await asyncio.sleep(2)
        
        await context.bot.delete_message(
            chat_id=query.message.chat_id, 
            message_id=animation_msg.message_id
        )
        
        await query.edit_message_text(
            f"❌ {user.full_name}, этот ключ не подходит к сундуку!\n\n"
            f"💸 Проигрыш: {format_number(game_data['bet'])} Vscoin\n"
            f"💰 Новый баланс: {format_number(user_data['balance'])} Vscoin"
        )
    
    user_data['active_game'] = None
    db.update_user(user.id, user_data)
    
    await query.answer()


# Генерация точки краша
def generate_crash_point():
    """Генерация точки краша"""
    rand = random.random()  # случайное число от 0 до 1
    
    # 75% шанс на 1-2x
    if rand <= 0.75:
        # Из этих 75%:
        # 52.5% общего (70% от 75%) на 1.01-1.5x
        if random.random() < 0.70:
            return round(random.uniform(1.01, 1.5), 2)
        # 22.5% общего (30% от 75%) на 1.5-2x
        else:
            return round(random.uniform(1.5, 2.0), 2)
    
    # 7% шанс на 2-5x (75%-82%)
    elif rand <= 0.82:
        return round(random.uniform(2.0, 5.0), 2)
    
    # 5% шанс на 5-10x (82%-87%)
    elif rand <= 0.87:
        return round(random.uniform(5.0, 10.0), 2)
    
    # 4% шанс на 10-30x (87%-91%)
    elif rand <= 0.91:
        return round(random.uniform(10.0, 30.0), 2)
    
    # 3% шанс на 30-100x (91%-94%)
    elif rand <= 0.94:
        return round(random.uniform(30.0, 100.0), 2)
    
    # 3% шанс на 100-500x (94%-97%)
    elif rand <= 0.97:
        return round(random.uniform(100.0, 500.0), 2)
    
    # 2% шанс на 500-2000x (97%-99%)
    elif rand <= 0.99:
        return round(random.uniform(500.0, 2000.0), 2)
    
    # 1% шанс на 2000-10000x (99%-100%)
    else:
        return round(random.uniform(2000.0, 10000.0), 2)
# Основная команда краша - назовем её crash_game
async def crash_game(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Проверка бана
    if user_data.get('banned', False):
        await update.message.reply_text("❌ Вы забанены!")
        return
    
    # Проверка аргументов
    if len(context.args) < 1:
        help_text = (
            "🚀 <b>ИГРА КРАШ</b>\n\n"
            "Ракета взлетает и падает на случайном множителе\n"
            "Вы выигрываете, если она долетела до вашего множителя\n\n"
            "<b>Формат:</b> <code>/краш [ставка] [множитель]</code>\n"
            "<b>Примеры:</b>\n"
            "<code>/краш 100 2</code> - ставка 100, выигрыш если ракета долетела до x2\n"
            "<code>/краш 1к 5</code> - ставка 1000, выигрыш если ракета долетела до x5\n"
            "<code>/краш 10к 10</code> - ставка 10000, выигрыш если ракета долетела до x10\n\n"
            "<b>Максимальный множитель:</b> x100,000\n"
            "<b>Шансы:</b> 1-2x (40%) | 2-5x (25%) | 5-10x (15%) | 10-30x (10%) | 30-100x (8%) | 100-1000x (1.9%) | 1000-100кx (0.1%)"
        )
        await update.message.reply_text(help_text, parse_mode='HTML')
        return
    
    try:
        # Парсим ставку
        bet_arg = context.args[0].lower()
        bet = parse_bet(bet_arg, user_data['balance'])
        
        if bet <= 0:
            await update.message.reply_text("❌ Ставка должна быть больше 0!")
            return
            
        if user_data['balance'] < bet:
            await update.message.reply_text(f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])}")
            return
    
    except Exception as e:
        await update.message.reply_text("❌ Неверный формат ставки!")
        return
    
    # Парсим множитель
    target_multiplier = 1.0
    
    if len(context.args) >= 2:
        try:
            mult_arg = context.args[1].lower()
            
            if 'к' in mult_arg:
                target_multiplier = float(mult_arg.replace('к', '')) * 1000
            elif 'x' in mult_arg:
                target_multiplier = float(mult_arg.replace('x', ''))
            else:
                target_multiplier = float(mult_arg)
            
            if target_multiplier < 1.01 or target_multiplier > 100000:
                await update.message.reply_text("❌ Множитель должен быть от 1.01 до 100,000")
                return
                
        except:
            await update.message.reply_text("❌ Неверный формат множителя! Пример: /краш 100 5")
            return
    else:
        await update.message.reply_text("❌ Укажите множитель! Пример: /краш 100 5")
        return
    
    # Списываем ставку
    user_data['balance'] -= bet
    db.update_user(user.id, user_data)
    
    # Отправляем сообщение о запуске
    launch_msg = await update.message.reply_text(
        f"🚀 <b>{user.full_name}</b> запускает ракету...\n"
        f"Ставка: {format_number(bet)}\n"
        f"Цель: x{target_multiplier:.2f}",
        parse_mode='HTML'
    )
    
    # Задержка
    await asyncio.sleep(2)
    
    # Генерируем точку краша
    crash_point = generate_crash_point()
    
    # Определяем результат
    if crash_point >= target_multiplier:
        # ВЫИГРЫШ
        win_amount = int(bet * target_multiplier)
        profit = win_amount - bet
        
        # Начисляем выигрыш
        user_data['balance'] += win_amount
        user_data['games_played'] += 1
        user_data['wins'] += 1
        user_data['won_amount'] += profit
        db.update_user(user.id, user_data)
        
        # Формируем сообщение о выигрыше
        result_text = (
            f"<b>{user.full_name}</b>\n"
            f"🚀 Ракета остановилась на x{crash_point:.2f} 📈\n"
            f"·····················\n"
            f"✅ Ты выиграл! Твой выигрыш составил {format_number(win_amount)}"
        )
        
        if profit > 0:
            result_text += f"\n💵 Прибыль: {format_number(profit)}"
            
        if target_multiplier >= 10:
            result_text += f"\n\n🎉 <b>БОЛЬШОЙ ВЫИГРЫШ!</b>"
            
    else:
        # ПРОИГРЫШ
        user_data['games_played'] += 1
        user_data['losses'] += 1
        user_data['lost_amount'] += bet
        db.update_user(user.id, user_data)
        
        # Формируем сообщение о проигрыше
        result_text = (
            f"<b>{user.full_name}</b>\n"
            f"🚀 Ракета упала на x{crash_point:.2f} 📉\n"
            f"·····················\n"
            f"❌ Ты проиграл {format_number(bet)}"
        )
        
        result_text += f"\n🎯 Цель была: x{target_multiplier:.2f}"
        
        if crash_point < 1.5:
            result_text += f"\n\n😞 Почти взлетела..."
    
    # Удаляем сообщение о запуске
    try:
        await context.bot.delete_message(
            chat_id=update.message.chat_id,
            message_id=launch_msg.message_id
        )
    except:
        pass
    
    # Отправляем финальный результат
    await update.message.reply_text(result_text, parse_mode='HTML')

   
    
    
# ... (весь предыдущий код до админ-панели остаётся без изменений) ...

# ==================== АДМИН ПАНЕЛЬ ====================

# ============ СИСТЕМА ХЕЛПЕРОВ ============

# Отдельные функции для каждой команды
async def helper1_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Назначить помощника 1 ранга"""
    await set_helper_rank_func(update, context, 1)

async def helper2_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Назначить помощника 2 ранга"""
    await set_helper_rank_func(update, context, 2)

async def helper3_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Назначить помощника 3 ранга"""
    await set_helper_rank_func(update, context, 3)

async def remove_helper_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Снять права помощника"""
    await set_helper_rank_func(update, context, 0)

async def set_helper_rank_func(update: Update, context: ContextTypes.DEFAULT_TYPE, rank: int):
    """Общая функция для установки ранга"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False):
        await update.message.reply_text("❌ Только администраторы могут использовать эту команду")
        return
    
    if not context.args:
        await update.message.reply_text(f"❌ Использование: /хелпер{rank if rank > 0 else 'снять'} @username")
        return
    
    target_username = context.args[0].replace('@', '')
    
    # Поиск пользователя
    target_id = None
    target_name = ""
    
    # Сначала ищем по username
    for uid, data in db.data.items():
        if data.get('username', '').lower() == target_username.lower():
            target_id = int(uid)
            target_name = data.get('username', 'Пользователь')
            break
    
    # Если не нашли, пробуем как ID
    if not target_id and target_username.isdigit():
        target_id = int(target_username)
        if str(target_id) in db.data:
            target_name = db.data[str(target_id)].get('username', 'Пользователь')
    
    if not target_id:
        await update.message.reply_text("❌ Пользователь не найден")
        return
    
    target_data = db.get_user(target_id)
    
    # Проверяем, не пытаемся ли назначить админа
    if target_data.get('is_admin', False):
        await update.message.reply_text("❌ Нельзя изменить ранг администратора")
        return
    
    if rank == 0:
        # Снятие прав
        old_rank = target_data.get('helper_rank', 0)
        db.set_helper_rank(target_id, 0)
        
        # Логируем
        db.log_helper_action(
            user.id,
            "Снятие прав помощника",
            f"Снял права у {target_name} (был ранг {old_rank})"
        )
        
        await update.message.reply_text(f"✅ С {target_name} сняты права помощника")
        
        # Уведомляем пользователя
        try:
            await context.bot.send_message(
                chat_id=target_id,
                text=f"ℹ️ <b>Ваши права помощника сняты</b>\n\n"
                     f"Администратор {user.full_name} снял с вас права помощника.",
                parse_mode=ParseMode.HTML
            )
        except:
            pass
    else:
        # Назначение помощника
        old_rank = target_data.get('helper_rank', 0)
        db.set_helper_rank(target_id, rank)
        rank_name = config.HELPER_RANKS[rank]["name"]
        
        # Логируем
        db.log_helper_action(
            user.id,
            "Назначение помощника",
            f"Назначил {target_name} на ранг {rank} ({rank_name})"
        )
        
        await update.message.reply_text(f"✅ {target_name} назначен {rank_name}")
        
        # Уведомляем пользователя
        try:
            rank_permissions = config.HELPER_RANKS[rank].get('permissions', [])
            permissions_text = "\n".join([f"• {p}" for p in rank_permissions])
            
            await context.bot.send_message(
                chat_id=target_id,
                text=f"🎖 <b>Поздравляем! Вам назначен новый статус!</b>\n\n"
                     f"🏆 Новый ранг: {rank_name}\n"
                     f"👤 Назначил: {user.full_name}\n\n"
                     f"📋 <b>Ваши права:</b>\n{permissions_text}\n\n"
                     f"Используйте команду /helper для доступа к панели помощника.",
                parse_mode=ParseMode.HTML
            )
        except:
            pass

# ==================== ПОЛНАЯ СИСТЕМА ХЕЛПЕР ПАНЕЛИ ====================

# ==================== ПОЛНЫЙ КОД ПАНЕЛИ ХЕЛПЕРА ====================

async def helper_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда /helper - панель хелпера"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    # Проверяем, является ли хелпером
    helper_rank = user_data.get('helper_rank', 0)
    is_admin = user_data.get('is_admin', False)
    
    if helper_rank == 0 and not is_admin:
        await update.message.reply_text("❌ У вас нет доступа к панели хелперов")
        return
    
    # Получаем количество выговоров
    warnings = user_data.get('helper_warnings', 0)
    
    # Определяем ранг
    rank_names = {
        1: "Младший Хелпер",
        2: "Хелпер", 
        3: "Старший Хелпер",
        4: "Куратор Хелперов"
    }
    
    rank_name = rank_names.get(helper_rank, "Игрок")
    
    # Если админ, показываем как куратор
    if is_admin:
        rank_name = "Администратор"
    
    # Формируем текст
    helper_text = (
        f"🛡 <b>ПАНЕЛЬ ХЕЛПЕРА</b>\n\n"
        f"👤 <b>Ник:</b> {user.full_name}\n"
        f"🆔 <b>ID:</b> {user.id}\n"
        f"⭐ <b>Ранг:</b> {rank_name}\n"
        f"⚠️ <b>Выговоры:</b> {warnings}/3\n\n"
        f"📊 <b>Статистика бота:</b>\n"
    )
    
    # Получаем статистику
    stats = db.get_statistics()
    helper_text += f"👥 Игроков: {stats['total_users']}\n"
    helper_text += f"💰 Общий баланс: {format_number(stats['total_balance'])} Vscoin\n"
    helper_text += f"🎮 Всего игр: {stats['total_games']}\n"
    helper_text += f"🛡 Хелперов: {stats['helpers']}\n"
    helper_text += f"🚫 Забанено: {stats['banned']}\n"
    
    if helper_rank >= 2 or is_admin:
        helper_text += f"📝 Ожидает банов: {stats['pending_bans']}\n"
        helper_text += f"💳 Ожидает кредитов: {stats['pending_credits']}\n"
    
    helper_text += f"\n📅 <i>Обновлено: {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}</i>"
    
    # Создаем клавиатуру в зависимости от ранга
    keyboard = []
    
    # Для Младшего Хелпера (1 ранг)
    if helper_rank == 1:
        keyboard.append([InlineKeyboardButton("📝 Заявка на бан", callback_data="helper_ban_request")])
        keyboard.append([InlineKeyboardButton("📊 Статистика бота", callback_data="helper_stats")])
    
    # Для Хелпера (2 ранг) - ВСЕ что у 1 ранга + новые функции
    elif helper_rank >= 2 or is_admin:
        keyboard.append([InlineKeyboardButton("📝 Заявки на бан", callback_data="helper_view_ban_requests")])
        keyboard.append([InlineKeyboardButton("🚫 Бан пользователя", callback_data="helper_ban_user")])
        keyboard.append([InlineKeyboardButton("✅ Разбан пользователя", callback_data="helper_unban_user")])
        keyboard.append([InlineKeyboardButton("📊 Статистика бота", callback_data="helper_stats")])
        keyboard.append([InlineKeyboardButton("💳 Заявки на кредит", callback_data="helper_credit_requests")])
    
    # Для Старшего Хелпера (3 ранг) - ВСЕ что у 2 ранга + новые функции
    if helper_rank >= 3 or is_admin:
        keyboard.append([InlineKeyboardButton("🎫 Создать промокод", callback_data="helper_create_promo")])
    
    # Для Куратора Хелперов (4 ранг) и Админа - ВСЕ что у 3 ранга + новые функции
    if helper_rank >= 4 or is_admin:
        keyboard.append([InlineKeyboardButton("👥 Управление хелперами", callback_data="helper_manage_helpers")])
    
    keyboard.append([InlineKeyboardButton("❌ Закрыть", callback_data="helper_close")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        helper_text,
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def helper_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик кнопок панели хелпера"""
    query = update.callback_query
    user = query.from_user
    user_data = db.get_user(user.id)
    
    helper_rank = user_data.get('helper_rank', 0)
    is_admin = user_data.get('is_admin', False)
    data = query.data
    
    await query.answer()
    
    if data == "helper_close":
        await query.message.delete()
        return
    
    # ЗАЯВКА НА БАН (1 ранг)
    if data == "helper_ban_request":
        if helper_rank < 1 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        context.user_data['awaiting_ban_request'] = True
        context.user_data['ban_request_type'] = 'request'
        context.user_data['ban_user_id'] = user.id
        
        await query.edit_message_text(
            "📝 <b>ЗАЯВКА НА БАН</b>\n\n"
            "Заполните по форме:\n"
            "<code>@username/ID количество_дней причина</code>\n\n"
            "<b>Примеры:</b>\n"
            "<code>@username 7 Спам</code>\n"
            "<code>123456789 3 Оскорбление</code>\n\n"
            "Отправьте данные в этом сообщении:",
            parse_mode=ParseMode.HTML
        )
        return
    
    # ПРОСМОТР ЗАЯВОК НА БАН (2+ ранг)
    elif data == "helper_view_ban_requests":
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        pending_requests = db.get_pending_ban_requests()
        
        if not pending_requests:
            await query.edit_message_text(
                "📝 <b>ЗАЯВКИ НА БАН</b>\n\n"
                "Нет ожидающих заявок на бан ✅",
                parse_mode=ParseMode.HTML
            )
            return
        
        # Показываем первую заявку
        request = pending_requests[0]
        
        request_text = (
            f"📋 <b>ЗАЯВКА #{request['id']}</b>\n\n"
            f"👤 <b>От:</b> {request['requester_name']}\n"
            f"🆔 <b>ID отправителя:</b> {request['requester_id']}\n\n"
            f"🎯 <b>Цель:</b> {request['target_name']}\n"
            f"🆔 <b>ID цели:</b> {request['target_id']}\n\n"
            f"⏰ <b>Срок:</b> {request['days']} дней\n"
            f"📝 <b>Причина:</b> {request['reason']}\n\n"
            f"📅 <b>Создана:</b> {request['created_at']}"
        )
        
        keyboard = [
            [
                InlineKeyboardButton("✅ Одобрить", callback_data=f"helper_approve_ban_{request['id']}"),
                InlineKeyboardButton("❌ Отклонить", callback_data=f"helper_reject_ban_{request['id']}")
            ],
            [InlineKeyboardButton("📋 Следующая", callback_data="helper_next_ban_request_1")],
            [InlineKeyboardButton("🔙 Назад", callback_data="helper_back")]
        ]
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            request_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # БАН ПОЛЬЗОВАТЕЛЯ (2+ ранг)
    elif data == "helper_ban_user":
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        context.user_data['awaiting_ban_request'] = True
        context.user_data['ban_request_type'] = 'direct'
        context.user_data['ban_user_id'] = user.id
        
        await query.edit_message_text(
            "🚫 <b>БАН ПОЛЬЗОВАТЕЛЯ</b>\n\n"
            "Заполните по форме:\n"
            "<code>@username/ID количество_дней причина</code>\n\n"
            "<b>Примеры:</b>\n"
            "<code>@username 7 Спам</code>\n"
            "<code>123456789 3 Оскорбление</code>\n\n"
            "Отправьте данные в этом сообщении:",
            parse_mode=ParseMode.HTML
        )
        return
    
    # РАЗБАН ПОЛЬЗОВАТЕЛЯ (2+ ранг)
    elif data == "helper_unban_user":
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        context.user_data['awaiting_unban'] = True
        context.user_data['unban_user_id'] = user.id
        
        await query.edit_message_text(
            "✅ <b>РАЗБАН ПОЛЬЗОВАТЕЛЯ</b>\n\n"
            "Введите username или ID пользователя:\n"
            "<code>@username</code> или <code>ID</code>\n\n"
            "Отправьте в этом сообщении:",
            parse_mode=ParseMode.HTML
        )
        return
    
    # СТАТИСТИКА БОТА
    elif data == "helper_stats":
        stats = db.get_statistics()
        stats_text = (
            "📊 <b>СТАТИСТИКА БОТА</b>\n\n"
            f"👥 <b>Всего пользователей:</b> {stats['total_users']}\n"
            f"💰 <b>Общий баланс:</b> {format_number(stats['total_balance'])} Vscoin\n"
            f"🎮 <b>Всего игр:</b> {stats['total_games']}\n"
            f"🛡 <b>Хелперов:</b> {stats['helpers']}\n"
            f"🚫 <b>Забанено:</b> {stats['banned']}\n"
            f"📝 <b>Ожидает банов:</b> {stats['pending_bans']}\n"
            f"💳 <b>Ожидает кредитов:</b> {stats['pending_credits']}\n\n"
            f"📅 <i>{datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}</i>"
        )
        
        keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data="helper_back")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(stats_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
        return
    
    # ЗАЯВКИ НА КРЕДИТ (2+ ранг) - НОВЫЙ ИНТЕРФЕЙС
    elif data == "helper_credit_requests":
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        await helper_credit_requests_ui(query, context, page=0)
        return
    
    # СОЗДАНИЕ ПРОМОКОДА (3+ ранг)
    elif data == "helper_create_promo":
        if helper_rank < 3 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        context.user_data['awaiting_promo'] = True
        context.user_data['promo_user_id'] = user.id
        
        await query.edit_message_text(
            "🎫 <b>СОЗДАНИЕ ПРОМОКОДА</b>\n\n"
            "Заполните по форме:\n"
            "<code>КОД СУММА КОЛИЧЕСТВО_АКТИВАЦИЙ</code>\n\n"
            "<b>Примеры:</b>\n"
            "<code>SUMMER2024 1000 50</code>\n"
            "<code>WELCOME 5000 1</code>\n\n"
            "Отправьте в этом сообщении:",
            parse_mode=ParseMode.HTML
        )
        return
    
    # УПРАВЛЕНИЕ ХЕЛПЕРАМИ (4+ ранг или админ)
    elif data == "helper_manage_helpers":
        if helper_rank < 4 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        # Получаем всех хелперов
        helpers = []
        for user_id, user_data_item in db.data.items():
            if user_data_item.get('helper_rank', 0) > 0:
                helpers.append({
                    'id': int(user_id),
                    'username': user_data_item.get('username', f'ID:{user_id}'),
                    'rank': user_data_item.get('helper_rank', 0),
                    'warnings': user_data_item.get('helper_warnings', 0)
                })
        
        if not helpers:
            await query.edit_message_text(
                "👥 <b>УПРАВЛЕНИЕ ХЕЛПЕРАМИ</b>\n\n"
                "Нет активных хелперов",
                parse_mode=ParseMode.HTML
            )
            return
        
        # Создаем кнопки для хелперов
        keyboard = []
        for helper in helpers[:10]:  # Ограничиваем 10 кнопками
            rank_emoji = {1: "🟢", 2: "🟡", 3: "🔴", 4: "👑"}.get(helper['rank'], "⚪")
            warning_text = f" ⚠️{helper['warnings']}" if helper['warnings'] > 0 else ""
            button_text = f"{rank_emoji} {helper['username']}{warning_text}"
            keyboard.append([InlineKeyboardButton(button_text, 
                callback_data=f"helper_manage_{helper['id']}")])
        
        keyboard.append([InlineKeyboardButton("🔙 Назад", callback_data="helper_back")])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "👥 <b>УПРАВЛЕНИЕ ХЕЛПЕРАМИ</b>\n\n"
            "Выберите хелпера для управления:",
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # НАЗАД К ПАНЕЛИ
    elif data == "helper_back":
        fake_update = Update(update.update_id, message=query.message)
        await helper_command(fake_update, context)
        return
    
    # ОДОБРЕНИЕ/ОТКЛОНЕНИЕ ЗАЯВОК
    elif data.startswith("helper_approve_ban_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        request_id = data.replace("helper_approve_ban_", "")
        
        if db.approve_ban_request(request_id, user.id):
            db.log_helper_action(
                user.id,
                'approve_ban',
                f'Одобрил заявку на бан #{request_id}'
            )
            
            await query.edit_message_text(
                f"✅ <b>ЗАЯВКА ОДОБРЕНА</b>\n\n"
                f"Заявка #{request_id} успешно одобрена.\n"
                f"Пользователь забанен.",
                parse_mode=ParseMode.HTML
            )
        else:
            await query.edit_message_text("❌ Ошибка: заявка не найдена")
        return
    
    elif data.startswith("helper_reject_ban_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        request_id = data.replace("helper_reject_ban_", "")
        
        if db.reject_ban_request(request_id, user.id):
            db.log_helper_action(
                user.id,
                'reject_ban',
                f'Отклонил заявку на бан #{request_id}'
            )
            
            await query.edit_message_text(
                f"❌ <b>ЗАЯВКА ОТКЛОНЕНА</b>\n\n"
                f"Заявка #{request_id} отклонена.",
                parse_mode=ParseMode.HTML
            )
        else:
            await query.edit_message_text("❌ Ошибка: заявка не найдена")
        return
    
    # ПРОСМОТР КОНКРЕТНОЙ ЗАЯВКИ НА КРЕДИТ
    elif data.startswith("helper_view_credit_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        parts = data.split('_')
        user_id = int(parts[3])
        amount = int(parts[4])
        term = int(parts[5])
        
        # Находим заявку
        pending_credits = db.get_pending_credit_requests()
        credit_request = None
        
        for req in pending_credits:
            if (req['user_id'] == user_id and 
                req['credit_data']['amount'] == amount and
                req['credit_data']['term'] == term):
                credit_request = req
                break
        
        if not credit_request:
            await query.edit_message_text("❌ Заявка не найдена или уже обработана")
            return
        
        user_data_req = credit_request['user_data']
        credit_data = credit_request['credit_data']
        
        # Полная информация о пользователе
        user_stats = f"👤 <b>Пользователь:</b> {user_data_req.get('username', 'Без имени')}\n"
        user_stats += f"🆔 <b>ID:</b> {user_id}\n"
        user_stats += f"💰 <b>Баланс:</b> {format_number(user_data_req.get('balance', 0))} Vscoin\n"
        user_stats += f"🎮 <b>Игр сыграно:</b> {user_data_req.get('games_played', 0)}\n"
        user_stats += f"📅 <b>Регистрация:</b> {user_data_req.get('registration_date', 'Неизвестно')}\n\n"
        
        credit_info = f"💳 <b>ЗАЯВКА НА КРЕДИТ</b>\n\n"
        credit_info += user_stats
        credit_info += f"<b>Сумма кредита:</b> {format_number(amount)} Vscoin\n"
        credit_info += f"<b>Срок:</b> {term} дней\n"
        credit_info += f"<b>Процентная ставка:</b> {credit_data['interest']}%\n"
        credit_info += f"<b>К возврату:</b> {format_number(int(amount * (1 + credit_data['interest']/100)))} Vscoin\n\n"
        credit_info += f"<b>Подана:</b> {credit_data['application_date']}"
        
        keyboard = [
            [
                InlineKeyboardButton("✅ Одобрить", 
                    callback_data=f"helper_approve_credit_{user_id}_{amount}_{term}"),
                InlineKeyboardButton("❌ Отклонить", 
                    callback_data=f"helper_reject_credit_{user_id}_{amount}_{term}")
            ],
            [InlineKeyboardButton("🔙 К списку", callback_data="helper_credit_requests")]
        ]
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(credit_info, parse_mode=ParseMode.HTML, reply_markup=reply_markup)
        return
    
    # ПАГИНАЦИЯ КРЕДИТОВ
    elif data.startswith("helper_credits_page_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        page = int(data.split('_')[3])
        await helper_credit_requests_ui(query, context, page=page)
        return
    
    # ОДОБРЕНИЕ/ОТКЛОНЕНИЕ КРЕДИТОВ
    elif data.startswith("helper_approve_credit_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        parts = data.split('_')
        user_id = int(parts[3])
        amount = int(parts[4])
        term = int(parts[5])
        
        if db.approve_credit_request(user_id, amount, term, user.id):
            db.log_helper_action(
                user.id,
                'approve_credit',
                f'Одобрил кредит {format_number(amount)} Vscoin на {term} дней для ID:{user_id}'
            )
            
            await query.edit_message_text(
                f"✅ <b>КРЕДИТ ОДОБРЕН</b>\n\n"
                f"Кредит {format_number(amount)} Vscoin на {term} дней одобрен.\n"
                f"Деньги зачислены на баланс пользователя.",
                parse_mode=ParseMode.HTML
            )
        else:
            await query.edit_message_text("❌ Ошибка: не удалось одобрить кредит")
        return
    
    elif data.startswith("helper_reject_credit_"):
        if helper_rank < 2 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        parts = data.split('_')
        user_id = int(parts[3])
        amount = int(parts[4])
        term = int(parts[5])
        
        # Находим и удаляем заявку
        user_data_req = db.get_user(user_id)
        if 'credits' in user_data_req:
            user_data_req['credits'] = [credit for credit in user_data_req['credits'] 
                                       if not (credit['amount'] == amount and 
                                               credit['term'] == term and 
                                               credit['status'] == 'pending')]
            db.update_user(user_id, user_data_req)
            
            db.log_helper_action(
                user.id,
                'reject_credit',
                f'Отклонил кредит {format_number(amount)} Vscoin на {term} дней для ID:{user_id}'
            )
            
            await query.edit_message_text(
                f"❌ <b>КРЕДИТ ОТКЛОНЕН</b>\n\n"
                f"Кредитная заявка отклонена.",
                parse_mode=ParseMode.HTML
            )
        else:
            await query.edit_message_text("❌ Ошибка: заявка не найдена")
        return
    
    # УПРАВЛЕНИЕ КОНКРЕТНЫМ ХЕЛПЕРОМ
    elif data.startswith("helper_manage_"):
        if helper_rank < 4 and not is_admin:
            await query.answer("❌ У вас недостаточно прав")
            return
        
        target_id = int(data.replace("helper_manage_", ""))
        target_data = db.get_user(target_id)
        
        rank_names = {1: "Младший Хелпер", 2: "Хелпер", 3: "Старший Хелпер", 4: "Куратор Хелперов"}
        rank_name = rank_names.get(target_data.get('helper_rank', 0), "Игрок")
        warnings = target_data.get('helper_warnings', 0)
        
        manage_text = (
            f"👤 <b>УПРАВЛЕНИЕ ХЕЛПЕРОМ</b>\n\n"
            f"<b>Ник:</b> {target_data.get('username', f'ID:{target_id}')}\n"
            f"<b>ID:</b> {target_id}\n"
            f"<b>Ранг:</b> {rank_name}\n"
            f"<b>Выговоры:</b> {warnings}/3\n\n"
            f"<b>Выберите действие:</b>"
        )
        
        keyboard = []
        
        if warnings < 3:
            keyboard.append([InlineKeyboardButton("⚠️ Дать выговор", 
                callback_data=f"helper_warn_{target_id}")])
        
        if warnings > 0:
            keyboard.append([InlineKeyboardButton("✅ Снять выговор", 
                callback_data=f"helper_unwarn_{target_id}")])
        
        keyboard.append([InlineKeyboardButton("💰 Выдать премию", 
            callback_data=f"helper_bonus_{target_id}")])
        
        if not target_data.get('is_admin', False):
            keyboard.append([InlineKeyboardButton("🗑 Снять с хелпера", 
                callback_data=f"helper_remove_{target_id}")])
        
        keyboard.append([InlineKeyboardButton("🔙 Назад", callback_data="helper_manage_helpers")])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            manage_text,
            parse_mode=ParseMode.HTML,
            reply_markup=reply_markup
        )
        return
    
    # ДЕЙСТВИЯ С ХЕЛПЕРАМИ
    elif data.startswith("helper_warn_"):
        target_id = int(data.replace("helper_warn_", ""))
        target_data = db.get_user(target_id)
        
        warnings = target_data.get('helper_warnings', 0) + 1
        target_data['helper_warnings'] = warnings
        
        if warnings >= 3:
            old_rank = target_data.get('helper_rank', 0)
            target_data['helper_rank'] = 0
            target_data['status'] = "Игрок"
            
            db.update_user(target_id, target_data)
            
            db.log_helper_action(
                user.id,
                'auto_remove_helper',
                f'Автоматически снял хелпера ID:{target_id} за 3 выговора'
            )
            
            await query.edit_message_text(
                f"⚠️ <b>ХЕЛПЕР СНЯТ АВТОМАТИЧЕСКИ</b>\n\n"
                f"Хелпер ID:{target_id} получил 3 выговора и был автоматически снят.",
                parse_mode=ParseMode.HTML
            )
        else:
            db.update_user(target_id, target_data)
            
            db.log_helper_action(
                user.id,
                'warn_helper',
                f'Выдал выговор хелперу ID:{target_id}. Теперь выговоров: {warnings}/3'
            )
            
            await query.edit_message_text(
                f"⚠️ <b>ВЫГОВОР ВЫДАН</b>\n\n"
                f"Хелпер ID:{target_id} получил выговор.\n"
                f"Теперь выговоров: {warnings}/3",
                parse_mode=ParseMode.HTML
            )
        return
    
    elif data.startswith("helper_unwarn_"):
        target_id = int(data.replace("helper_unwarn_", ""))
        target_data = db.get_user(target_id)
        
        warnings = max(0, target_data.get('helper_warnings', 0) - 1)
        target_data['helper_warnings'] = warnings
        
        db.update_user(target_id, target_data)
        
        db.log_helper_action(
            user.id,
            'unwarn_helper',
            f'Снял выговор хелперу ID:{target_id}. Теперь выговоров: {warnings}/3'
        )
        
        await query.edit_message_text(
            f"✅ <b>ВЫГОВОР СНЯТ</b>\n\n"
            f"С хелпера ID:{target_id} снят выговор.\n"
            f"Теперь выговоров: {warnings}/3",
            parse_mode=ParseMode.HTML
        )
        return
    
    elif data.startswith("helper_bonus_"):
        target_id = int(data.replace("helper_bonus_", ""))
        
        context.user_data['awaiting_helper_bonus'] = True
        context.user_data['bonus_target_id'] = target_id
        context.user_data['bonus_helper_id'] = user.id
        
        await query.edit_message_text(
            "💰 <b>ВЫДАЧА ПРЕМИИ</b>\n\n"
            "Введите сумму премии (максимум 10,000,000 Vscoin):\n\n"
            "Отправьте в этом сообщении:",
            parse_mode=ParseMode.HTML
        )
        return
    
    elif data.startswith("helper_remove_"):
        target_id = int(data.replace("helper_remove_", ""))
        target_data = db.get_user(target_id)
        
        old_rank = target_data.get('helper_rank', 0)
        
        target_data['helper_rank'] = 0
        target_data['status'] = "Игрок"
        target_data['helper_warnings'] = 0
        
        db.update_user(target_id, target_data)
        
        db.log_helper_action(
            user.id,
            'remove_helper',
            f'Снял хелпера ID:{target_id} (ранг: {old_rank})'
        )
        
        await query.edit_message_text(
            f"🗑 <b>ХЕЛПЕР СНЯТ</b>\n\n"
            f"Хелпер ID:{target_id} снят с должности.",
            parse_mode=ParseMode.HTML
        )
        return

async def helper_credit_requests_ui(query, context, page=0):
    """Улучшенный интерфейс заявок на кредит с пагинацией"""
    pending_credits = db.get_pending_credit_requests()
    
    if not pending_credits:
        await query.edit_message_text(
            "💳 <b>ЗАЯВКИ НА КРЕДИТ</b>\n\n"
            "Нет ожидающих заявок на кредит ✅",
            parse_mode=ParseMode.HTML
        )
        return
    
    # Пагинация (по 5 заявок на страницу)
    per_page = 5
    total_pages = (len(pending_credits) + per_page - 1) // per_page
    start_idx = page * per_page
    end_idx = min(start_idx + per_page, len(pending_credits))
    
    # Заголовок с пагинацией
    credit_text = (
        f"💳 <b>ЗАЯВКИ НА КРЕДИТ</b> (Страница {page+1}/{total_pages})\n\n"
    )
    
    # Список заявок
    keyboard = []
    for i, credit_req in enumerate(pending_credits[start_idx:end_idx], start=start_idx):
        user_data = credit_req['user_data']
        credit_data = credit_req['credit_data']
        
        display_name = user_data.get('username', f'ID:{credit_req["user_id"]}')
        if len(display_name) > 20:
            display_name = display_name[:17] + "..."
        
        credit_text += f"{i+1}. <b>{display_name}</b>\n"
        credit_text += f"   Сумма: {format_number(credit_data['amount'])} Vscoin\n"
        credit_text += f"   Срок: {credit_data['term']} дней\n\n"
        
        keyboard.append([InlineKeyboardButton(
            f"📋 {i+1}. {display_name} - {format_number(credit_data['amount'])} Vscoin",
            callback_data=f"helper_view_credit_{credit_req['user_id']}_{credit_data['amount']}_{credit_data['term']}"
        )])
    
    # Кнопки пагинации
    nav_buttons = []
    if page > 0:
        nav_buttons.append(InlineKeyboardButton("⬅️ Назад", callback_data=f"helper_credits_page_{page-1}"))
    
    if page < total_pages - 1:
        nav_buttons.append(InlineKeyboardButton("➡️ Вперед", callback_data=f"helper_credits_page_{page+1}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    keyboard.append([InlineKeyboardButton("🔙 Назад", callback_data="helper_back")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(credit_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

# ==================== ОБРАБОТКА ТЕКСТОВЫХ СООБЩЕНИЙ ХЕЛПЕРОВ ====================

async def handle_helper_text_messages(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик текстовых сообщений для хелперов"""
    user = update.effective_user
    text = update.message.text.strip()
    
    # 1. ЗАЯВКА НА БАН / БАН ПОЛЬЗОВАТЕЛЯ
    if context.user_data.get('awaiting_ban_request') and context.user_data.get('ban_user_id') == user.id:
        ban_type = context.user_data.get('ban_request_type', 'request')
        
        try:
            parts = text.split(' ', 2)
            if len(parts) < 3:
                await update.message.reply_text("❌ Неверный формат! Пример: @username 7 Спам")
                for key in ['awaiting_ban_request', 'ban_request_type', 'ban_user_id']:
                    if key in context.user_data:
                        del context.user_data[key]
                return
            
            target = parts[0]
            days = int(parts[1])
            reason = parts[2]
            
            if days < 1 or days > 365:
                await update.message.reply_text("❌ Количество дней: от 1 до 365")
                for key in ['awaiting_ban_request', 'ban_request_type', 'ban_user_id']:
                    if key in context.user_data:
                        del context.user_data[key]
                return
            
            # Ищем пользователя
            target_id = None
            target_name = target
            
            if target.startswith('@'):
                username = target[1:]
                target_id, target_data = db.get_user_by_username(username)
                if target_id:
                    target_name = target_data.get('username', username)
            elif target.isdigit():
                target_id = int(target)
                target_data = db.get_user(target_id)
                if target_data:
                    target_name = target_data.get('username', f'ID:{target_id}')
            
            if not target_id:
                await update.message.reply_text("❌ Пользователь не найден")
                for key in ['awaiting_ban_request', 'ban_request_type', 'ban_user_id']:
                    if key in context.user_data:
                        del context.user_data[key]
                return
            
            user_data = db.get_user(user.id)
            
            # Для Младшего Хелпера - создаем заявку
            if ban_type == 'request' and user_data.get('helper_rank', 0) == 1:
                request_id = db.create_ban_request(user.id, target_id, days, reason)
                
                db.log_helper_action(
                    user.id,
                    'create_ban_request',
                    f'Создал заявку на бан #{request_id} для {target_name}'
                )
                
                await update.message.reply_text(
                    f"📝 <b>ЗАЯВКА СОЗДАНА</b>\n\n"
                    f"Заявка #{request_id} на бан пользователя {target_name}\n"
                    f"на {days} дней отправлена на рассмотрение.\n"
                    f"<b>Причина:</b> {reason}",
                    parse_mode=ParseMode.HTML
                )
            
            # Для Хелпера 2+ ранга - сразу бан
            elif ban_type == 'direct' and user_data.get('helper_rank', 0) >= 2:
                target_data = db.get_user(target_id)
                target_data['banned'] = True
                target_data['ban_reason'] = reason
                ban_until = datetime.datetime.now() + datetime.timedelta(days=days)
                target_data['ban_until'] = ban_until.strftime("%d-%m-%Y %H:%M:%S")
                db.update_user(target_id, target_data)
                
                db.log_helper_action(
                    user.id,
                    'direct_ban',
                    f'Забанил {target_name} на {days} дней. Причина: {reason}'
                )
                
                await update.message.reply_text(
                    f"🚫 <b>ПОЛЬЗОВАТЕЛЬ ЗАБАНЕН</b>\n\n"
                    f"Пользователь {target_name}\n"
                    f"забанен на {days} дней.\n"
                    f"<b>Причина:</b> {reason}",
                    parse_mode=ParseMode.HTML
                )
            
            # Очищаем данные
            for key in ['awaiting_ban_request', 'ban_request_type', 'ban_user_id']:
                if key in context.user_data:
                    del context.user_data[key]
                    
        except ValueError:
            await update.message.reply_text("❌ Неверный формат! Пример: @username 7 Спам")
            for key in ['awaiting_ban_request', 'ban_request_type', 'ban_user_id']:
                if key in context.user_data:
                    del context.user_data[key]
        return
    
    # 2. РАЗБАН
    elif context.user_data.get('awaiting_unban') and context.user_data.get('unban_user_id') == user.id:
        target = text
        
        try:
            target_id = None
            
            if target.startswith('@'):
                username = target[1:]
                target_id, target_data = db.get_user_by_username(username)
            elif target.isdigit():
                target_id = int(target)
                target_data = db.get_user(target_id)
            
            if not target_id:
                await update.message.reply_text("❌ Пользователь не найден")
                del context.user_data['awaiting_unban']
                del context.user_data['unban_user_id']
                return
            
            target_data = db.get_user(target_id)
            
            if not target_data.get('banned', False):
                await update.message.reply_text("❌ Этот пользователь не забанен")
                del context.user_data['awaiting_unban']
                del context.user_data['unban_user_id']
                return
            
            db.unban_user(target_id)
            
            db.log_helper_action(
                user.id,
                'unban_user',
                f'Разбанил пользователя ID:{target_id}'
            )
            
            await update.message.reply_text(
                f"✅ <b>ПОЛЬЗОВАТЕЛЬ РАЗБАНЕН</b>\n\n"
                f"Пользователь {target_data.get('username', f'ID:{target_id}')}\n"
                f"успешно разбанен.",
                parse_mode=ParseMode.HTML
            )
            
            del context.user_data['awaiting_unban']
            del context.user_data['unban_user_id']
            
        except Exception as e:
            await update.message.reply_text(f"❌ Ошибка: {str(e)}")
            del context.user_data['awaiting_unban']
            del context.user_data['unban_user_id']
        return
    
    # 3. СОЗДАНИЕ ПРОМОКОДА
    elif context.user_data.get('awaiting_promo') and context.user_data.get('promo_user_id') == user.id:
        try:
            parts = text.split(' ', 2)
            if len(parts) < 3:
                await update.message.reply_text("❌ Неверный формат! Пример: SUMMER2024 1000 50")
                del context.user_data['awaiting_promo']
                del context.user_data['promo_user_id']
                return
            
            code = parts[0].upper()
            amount = int(parts[1])
            uses = int(parts[2])
            
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                del context.user_data['awaiting_promo']
                del context.user_data['promo_user_id']
                return
            
            if uses <= 0 or uses > 1000:
                await update.message.reply_text("❌ Количество активаций: от 1 до 1000")
                del context.user_data['awaiting_promo']
                del context.user_data['promo_user_id']
                return
            
            if code in db.promocodes:
                await update.message.reply_text("❌ Этот промокод уже существует")
                del context.user_data['awaiting_promo']
                del context.user_data['promo_user_id']
                return
            
            db.add_promocode(code, amount, uses)
            
            db.log_helper_action(
                user.id,
                'create_promo',
                f'Создал промокод {code} на {format_number(amount)} Vscoin, {uses} активаций'
            )
            
            await update.message.reply_text(
                f"🎫 <b>ПРОМОКОД СОЗДАН</b>\n\n"
                f"<b>Код:</b> {code}\n"
                f"<b>Сумма:</b> {format_number(amount)} Vscoin\n"
                f"<b>Активаций:</b> {uses}\n\n"
                f"Для активации: <code>/промо {code}</code>",
                parse_mode=ParseMode.HTML
            )
            
            del context.user_data['awaiting_promo']
            del context.user_data['promo_user_id']
            
        except ValueError:
            await update.message.reply_text("❌ Неверный формат! Пример: SUMMER2024 1000 50")
            del context.user_data['awaiting_promo']
            del context.user_data['promo_user_id']
        return
    
    # 4. ВЫДАЧА ПРЕМИИ ХЕЛПЕРУ
    elif context.user_data.get('awaiting_helper_bonus') and context.user_data.get('bonus_helper_id') == user.id:
        try:
            amount = parse_bet(text)
            target_id = context.user_data.get('bonus_target_id')
            
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                for key in ['awaiting_helper_bonus', 'bonus_target_id', 'bonus_helper_id']:
                    if key in context.user_data:
                        del context.user_data[key]
                return
            
            if amount > 10000000:
                await update.message.reply_text("❌ Максимальная премия: 10,000,000 Vscoin")
                for key in ['awaiting_helper_bonus', 'bonus_target_id', 'bonus_helper_id']:
                    if key in context.user_data:
                        del context.user_data[key]
                return
            
            target_data = db.get_user(target_id)
            target_data['balance'] += amount
            db.update_user(target_id, target_data)
            
            db.log_helper_action(
                user.id,
                'give_bonus',
                f'Выдал премию {format_number(amount)} Vscoin хелперу ID:{target_id}'
            )
            
            await update.message.reply_text(
                f"💰 <b>ПРЕМИЯ ВЫДАНА</b>\n\n"
                f"Хелпер {target_data.get('username', f'ID:{target_id}')}\n"
                f"получил премию: {format_number(amount)} Vscoin\n\n"
                f"<i>Теперь баланс: {format_number(target_data['balance'])} Vscoin</i>",
                parse_mode=ParseMode.HTML
            )
            
            for key in ['awaiting_helper_bonus', 'bonus_target_id', 'bonus_helper_id']:
                if key in context.user_data:
                    del context.user_data[key]
                    
        except ValueError:
            await update.message.reply_text("❌ Неверный формат суммы!")
            for key in ['awaiting_helper_bonus', 'bonus_target_id', 'bonus_helper_id']:
                if key in context.user_data:
                    del context.user_data[key]
        return



  

# Глобальные настройки бота - ДОЛЖНО БЫТЬ ДО ВСЕХ ФУНКЦИЙ
BOT_SETTINGS = {
    'enabled': True,
    'last_restart': datetime.datetime.now().strftime("%d-%m-%Y %H:%M")
}



async def admin_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False) and user.id not in ADMIN_IDS:
        if len(context.args) < 1:
            await update.message.reply_text("Использование: 'админ [пароль]'")
            return
        
        if context.args[0] != ADMIN_PASSWORD:
            await update.message.reply_text("Неверный пароль")
            return
        
        if user.id not in ADMIN_IDS:
            ADMIN_IDS.append(user.id)
        
        user_data['is_admin'] = True
        user_data['status'] = "Администратор"
        db.update_user(user.id, user_data)
    
    if not BOT_SETTINGS['enabled'] and not user_data.get('is_admin', False):
        await update.message.reply_text("❌ Бот временно отключен администратором")
        return
    
    keyboard = [
        [InlineKeyboardButton("👥 Пользователи", callback_data="admin_users")],
        [InlineKeyboardButton("🎫 Управление промокодами", callback_data="admin_promos")],
        [InlineKeyboardButton("📢 Управление рекламой", callback_data="admin_ads")],
        [InlineKeyboardButton("💱 Управление курсом", callback_data="admin_exchange")],
        [InlineKeyboardButton("💰 Кредитные заявки", callback_data="admin_credits")],
        [InlineKeyboardButton("📊 Статистика", callback_data="admin_stats")],
        [InlineKeyboardButton("⚙️ Настройки", callback_data="admin_settings")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🛠 <b>Панель администратора</b>\n\n"
        "Выберите раздел для управления:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def admin_users_panel(query, context):
    users = [(uid, data) for uid, data in db.data.items() if not data.get('is_admin', False)]
    
    context.user_data['admin_users_list'] = users
    context.user_data['admin_users_page'] = 0
    
    await show_users_page(query, context)

async def show_users_page(query, context, page=0):
    users = context.user_data.get('admin_users_list', [])
    users_per_page = 5
    total_pages = (len(users) + users_per_page - 1) // users_per_page
    
    start_idx = page * users_per_page
    end_idx = min(start_idx + users_per_page, len(users))
    
    keyboard = []
    
    for i in range(start_idx, end_idx):
        user_id, user_data = users[i]
        username = user_data.get('username', 'Unknown')
        balance = format_number(user_data.get('balance', 0))
        status = "🔨 Забанен" if user_data.get('banned', False) else "✅ Активен"
        
        keyboard.append([InlineKeyboardButton(
            f"{username} | {balance} Vscoin | {status}", 
            callback_data=f"admin_user_detail_{user_id}"
        )])
    
    nav_buttons = []
    if page > 0:
        nav_buttons.append(InlineKeyboardButton("⬅️ Назад", callback_data=f"admin_users_page_{page-1}"))
    if page < total_pages - 1:
        nav_buttons.append(InlineKeyboardButton("Вперед ➡️", callback_data=f"admin_users_page_{page+1}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    keyboard.append([InlineKeyboardButton("◀️ Назад", callback_data="admin_back")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"👥 <b>Управление пользователями</b>\n\n"
        f"Страница {page+1} из {total_pages}\n"
        f"Всего пользователей: {len(users)}",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def admin_user_detail(query, context):
    user_id = int(query.data.split('_')[3])
    user_data = db.get_user(user_id)
    
    keyboard = [
        [InlineKeyboardButton("💰 Выдать деньги", callback_data=f"admin_user_give_{user_id}")],
        [InlineKeyboardButton("💸 Забрать деньги", callback_data=f"admin_user_take_{user_id}")]
    ]
    
    if user_data.get('banned', False):
        keyboard.append([InlineKeyboardButton("🔓 Разбанить", callback_data=f"admin_user_unban_{user_id}")])
    else:
        keyboard.append([InlineKeyboardButton("🔨 Забанить", callback_data=f"admin_user_ban_{user_id}")])
    
    keyboard.append([InlineKeyboardButton("◀️ Назад к списку", callback_data="admin_users_back")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    ban_info = ""
    if user_data.get('banned', False):
        ban_until = user_data.get('ban_until', 'Не указано')
        ban_reason = user_data.get('ban_reason', 'Не указана')
        ban_info = f"\n🔨 Забанен до: {ban_until}\n📝 Причина: {ban_reason}"
    
    await query.edit_message_text(
        f"👤 <b>Информация о пользователе</b>\n\n"
        f"🆔 ID: {user_id}\n"
        f"📛 Имя: {user_data.get('username', 'Unknown')}\n"
        f"💰 Баланс: {format_number(user_data.get('balance', 0))} Vscoin\n"
        f"🪙 BTC: {user_data.get('bitcoin_balance', 0)}\n"
        f"🎮 Игр сыграно: {user_data.get('games_played', 0)}\n"
        f"📅 Регистрация: {user_data.get('registration_date', 'Unknown')}\n"
        f"🔨 Статус: {'Забанен' if user_data.get('banned', False) else 'Активен'}"
        f"{ban_info}",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def admin_user_give(query, context):
    user_id = int(query.data.split('_')[3])
    context.user_data['admin_action'] = {'type': 'give', 'user_id': user_id}
    
    await query.edit_message_text(
        "💰 <b>Выдача денег</b>\n\n"
        "Введите сумму для выдачи:",
        parse_mode=ParseMode.HTML
    )

async def admin_user_take(query, context):
    user_id = int(query.data.split('_')[3])
    context.user_data['admin_action'] = {'type': 'take', 'user_id': user_id}
    
    await query.edit_message_text(
        "💸 <b>Изъятие денег</b>\n\n"
        "Введите сумму для изъятия:",
        parse_mode=ParseMode.HTML
    )

async def admin_user_ban(query, context):
    user_id = int(query.data.split('_')[3])
    context.user_data['admin_action'] = {'type': 'ban', 'user_id': user_id}
    
    await query.edit_message_text(
        "🔨 <b>Бан пользователя</b>\n\n"
        "Введите количество дней и причину через пробел:\n"
        "Пример: <code>15 Оскорбление бота</code>",
        parse_mode=ParseMode.HTML
    )

async def admin_user_unban(query, context):
    user_id = int(query.data.split('_')[3])
    user_data = db.get_user(user_id)
    
    user_data['banned'] = False
    user_data['ban_reason'] = ''
    user_data['ban_until'] = ''
    
    db.update_user(user_id, user_data)
    
    await query.edit_message_text(
        f"✅ Пользователь {user_data.get('username', 'Unknown')} разбанен!"
    )
    
    try:
        await context.bot.send_message(
            chat_id=user_id,
            text="✅ <b>Вы были разбанены администратором!</b>\n\n"
                 "Теперь вы снова можете пользоваться ботом.",
            parse_mode=ParseMode.HTML
        )
    except:
        pass

async def handle_admin_user_actions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = update.message.text.strip()
    
    if 'admin_action' not in context.user_data:
        return
    
    action = context.user_data['admin_action']
    
    if action['type'] in ['give', 'take']:
        try:
            amount = parse_bet(text)
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной")
                return
            
            target_user_data = db.get_user(action['user_id'])
            
            if action['type'] == 'give':
                target_user_data['balance'] += amount
                await update.message.reply_text(
                    f"✅ Выдано {format_number(amount)} Vscoin пользователю {target_user_data.get('username', 'Unknown')}\n"
                    f"💰 Новый баланс: {format_number(target_user_data['balance'])} Vscoin"
                )
            else:
                if target_user_data['balance'] < amount:
                    amount = target_user_data['balance']
                target_user_data['balance'] -= amount
                await update.message.reply_text(
                    f"✅ Изъято {format_number(amount)} Vscoin у пользователя {target_user_data.get('username', 'Unknown')}\n"
                    f"💰 Новый баланс: {format_number(target_user_data['balance'])} Vscoin"
                )
            
            db.update_user(action['user_id'], target_user_data)
            
        except:
            await update.message.reply_text("❌ Неверный формат суммы")
    
    elif action['type'] == 'ban':
        parts = text.split(' ', 1)
        if len(parts) < 2:
            await update.message.reply_text("❌ Неверный формат. Используйте: дни причина")
            return
        
        try:
            days = int(parts[0])
            reason = parts[1]
            
            target_user_data = db.get_user(action['user_id'])
            
            target_user_data['banned'] = True
            target_user_data['ban_reason'] = reason
            target_user_data['ban_until'] = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime("%d-%m-%Y %H:%M")
            
            db.update_user(action['user_id'], target_user_data)
            
            await update.message.reply_text(
                f"✅ Пользователь {target_user_data.get('username', 'Unknown')} забанен на {days} дней\n"
                f"📝 Причина: {reason}"
            )
            
            try:
                await context.bot.send_message(
                    chat_id=action['user_id'],
                    text=f"❌ <b>Вы были забанены!</b>\n\n"
                         f"📅 Срок: {days} дней\n"
                         f"📝 Причина: {reason}\n"
                         f"🕒 Разбан: {target_user_data['ban_until']}\n\n"
                         f"Если вы считаете, что это ошибка, свяжитесь с поддержкой.",
                    parse_mode=ParseMode.HTML
                )
            except:
                pass
            
        except ValueError:
            await update.message.reply_text("❌ Неверный формат количества дней")
    
    del context.user_data['admin_action']

async def admin_promos_panel(query):
    keyboard = [
        [InlineKeyboardButton("➕ Создать промокод", callback_data="admin_promo_create")],
        [InlineKeyboardButton("🗑 Удалить промокод", callback_data="admin_promo_delete")],
        [InlineKeyboardButton("📋 Все промокоды", callback_data="admin_promo_list")],
        [InlineKeyboardButton("◀️ Назад", callback_data="admin_back")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "🎫 <b>Управление промокодами</b>\n\n"
        "Выберите действие:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def admin_promo_create_handler(query, context):
    context.user_data['admin_action'] = {'type': 'create_promo'}
    
    await query.edit_message_text(
        "➕ <b>Создание промокода</b>\n\n"
        "Введите данные в формате:\n"
        "<code>Название Сумма Количество_использований</code>\n\n"
        "Пример: <code>БотТоп 15000 15</code>\n"
        "• БотТоп - название промокода\n"
        "• 15000 - сумма вознаграждения\n"
        "• 15 - количество использований",
        parse_mode=ParseMode.HTML
    )

async def admin_promo_delete_handler(query, context):
    context.user_data['admin_action'] = {'type': 'delete_promo'}
    
    promos_text = "📋 <b>Активные промокоды:</b>\n\n"
    
    if not db.promocodes:
        promos_text += "Нет активных промокодов\n"
    else:
        for code, data in db.promocodes.items():
            used = len(data.get('used_by', []))
            total_uses = data.get('uses', 1)
            promos_text += f"• {code}: {format_number(data['amount'])} Vscoin (использовано {used}/{total_uses})\n"
    
    promos_text += "\nВведите название промокода для удаления:"
    
    await query.edit_message_text(promos_text, parse_mode=ParseMode.HTML)

async def admin_promo_list_handler(query):
    promos_text = "📋 <b>Все промокоды:</b>\n\n"
    
    if not db.promocodes:
        promos_text += "Нет активных промокодов"
    else:
        for code, data in db.promocodes.items():
            used = len(data.get('used_by', []))
            total_uses = data.get('uses', 1)
            remaining = total_uses - used
            promos_text += f"• <b>{code}</b>\n"
            promos_text += f"  💰 {format_number(data['amount'])} Vscoin\n"
            promos_text += f"  👥 Осталось использований: {remaining}/{total_uses}\n\n"
    
    keyboard = [[InlineKeyboardButton("◀️ Назад", callback_data="admin_promos_back")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(promos_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def handle_admin_promo_actions(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = update.message.text.strip()
    
    if 'admin_action' not in context.user_data:
        return
    
    action = context.user_data['admin_action']
    
    if action['type'] == 'create_promo':
        parts = text.split()
        if len(parts) < 3:
            await update.message.reply_text("❌ Неверный формат. Используйте: Название Сумма Количество")
            return
        
        code = parts[0].upper()
        try:
            amount = parse_bet(parts[1])
            uses = int(parts[2])
        except:
            await update.message.reply_text("❌ Неверный формат суммы или количества")
            return
        
        if code in db.promocodes:
            await update.message.reply_text("❌ Промокод с таким названием уже существует")
            return
        
        db.add_promocode(code, amount, uses)
        
        await update.message.reply_text(
            f"✅ Промокод успешно создан!\n\n"
            f"🎫 Название: <code>{code}</code>\n"
            f"💰 Сумма: {format_number(amount)} Vscoin\n"
            f"👥 Использований: {uses}\n\n"
            f"Пользователи могут активировать его командой: <code>промо {code}</code>",
            parse_mode=ParseMode.HTML
        )
    
    elif action['type'] == 'delete_promo':
        code = text.upper()
        
        if code in db.promocodes:
            del db.promocodes[code]
            db.save()
            await update.message.reply_text(f"✅ Промокод {code} успешно удален!")
        else:
            await update.message.reply_text("❌ Промокод не найден")
    
    del context.user_data['admin_action']

async def admin_stats_panel(query, context):
    total_users = len(db.data)
    
    active_users = 0
    total_balance = 0
    total_lost = 0
    
    ten_minutes_ago = datetime.datetime.now() - datetime.timedelta(minutes=10)
    
    for user_data in db.data.values():
        total_balance += user_data.get('balance', 0)
        total_lost += user_data.get('lost_amount', 0)
        
        if user_data.get('last_bonus'):
            last_active = datetime.datetime.strptime(user_data['last_bonus'], "%Y-%m-%d %H:%M:%S")
            if last_active > ten_minutes_ago:
                active_users += 1
    
    stats_text = (
        "📊 <b>Статистика бота</b>\n\n"
        f"👥 <b>Всего пользователей:</b> {total_users}\n"
        f"🎮 <b>Сейчас играют (за 10 мин):</b> {active_users}\n"
        f"💰 <b>Общий баланс пользователей:</b> {format_number(total_balance)} Vscoin\n"
        f"📉 <b>Всего проиграно:</b> {format_number(total_lost)} Vscoin\n"
        f"🕒 <b>Последнее обновление:</b> {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}\n"
        f"🔧 <b>Статус бота:</b> {'🟢 Включен' if BOT_SETTINGS['enabled'] else '🔴 Выключен'}\n"
        f"📅 <b>Последний перезапуск:</b> {BOT_SETTINGS['last_restart']}"
    )
    
    keyboard = [
        [InlineKeyboardButton("🔄 Обновить", callback_data="admin_stats")],
        [InlineKeyboardButton("◀️ Назад", callback_data="admin_back")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(stats_text, parse_mode=ParseMode.HTML, reply_markup=reply_markup)

async def admin_settings_panel(query):
    keyboard = [
        [InlineKeyboardButton("🔄 Перезагрузить бота", callback_data="admin_settings_restart")],
        [InlineKeyboardButton("🔴 Выключить бот", callback_data="admin_settings_disable")] if BOT_SETTINGS['enabled'] else 
        [InlineKeyboardButton("🟢 Включить бот", callback_data="admin_settings_enable")],
        [InlineKeyboardButton("🗑️ Удалить данные игроков", callback_data="admin_settings_clear")],
        [InlineKeyboardButton("◀️ Назад", callback_data="admin_back")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    status = "🟢 Включен" if BOT_SETTINGS['enabled'] else "🔴 Выключен"
    
    await query.edit_message_text(
        f"⚙️ <b>Настройки бота</b>\n\n"
        f"Текущий статус: {status}\n"
        f"Последний перезапуск: {BOT_SETTINGS['last_restart']}\n\n"
        f"Выберите действие:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def admin_settings_handler(query, context):
    action = query.data.split('_')[2]
    
    if action == 'restart':
        BOT_SETTINGS['last_restart'] = datetime.datetime.now().strftime("%d-%m-%Y %H:%M")
        await query.edit_message_text("✅ Бот перезагружен!")
        
    elif action == 'disable':
        BOT_SETTINGS['enabled'] = False
        await query.edit_message_text("🔴 Бот выключен. Только администраторы могут им пользоваться.")
        
    elif action == 'enable':
        BOT_SETTINGS['enabled'] = True
        await query.edit_message_text("🟢 Бот включен. Все пользователи могут им пользоваться.")
        
    elif action == 'clear':
        cleared_count = 0
        for user_id, user_data in db.data.items():
            if not user_data.get('is_admin', False):
                db.data[user_id] = {
                    'user_id': user_id,
                    'username': user_data.get('username', 'Unknown'),
                    'balance': 1000,
                    'bitcoin_balance': 0,
                    'games_played': 0,
                    'wins': 0,
                    'losses': 0,
                    'won_amount': 0,
                    'lost_amount': 0,
                    'registration_date': user_data.get('registration_date', datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
                    'last_bonus': user_data.get('last_bonus', ''),
                    'banned': user_data.get('banned', False),
                    'ban_reason': user_data.get('ban_reason', ''),
                    'ban_until': user_data.get('ban_until', ''),
                    'is_admin': user_data.get('is_admin', False),
                    'status': user_data.get('status', 'Пользователь')
                }
                cleared_count += 1
        
        db.save()
        await query.edit_message_text(f"✅ Данные {cleared_count} игроков очищены!")

async def admin_callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    data = query.data
    
    if data == "admin_back":
        await admin_panel_from_callback(query, context)
    
    elif data == "admin_users":
        await admin_users_panel(query, context)
    
    elif data.startswith("admin_users_page_"):
        page = int(data.split('_')[3])
        await show_users_page(query, context, page)
    
    elif data.startswith("admin_user_detail_"):
        await admin_user_detail(query, context)
    
    elif data == "admin_users_back":
        await admin_users_panel(query, context)
    
    elif data.startswith("admin_user_give_"):
        await admin_user_give(query, context)
    
    elif data.startswith("admin_user_take_"):
        await admin_user_take(query, context)
    
    elif data.startswith("admin_user_ban_"):
        await admin_user_ban(query, context)
    
    elif data.startswith("admin_user_unban_"):
        await admin_user_unban(query, context)
    
    elif data == "admin_promos":
        await admin_promos_panel(query)
    
    elif data == "admin_promo_create":
        await admin_promo_create_handler(query, context)
    
    elif data == "admin_promo_delete":
        await admin_promo_delete_handler(query, context)
    
    elif data == "admin_promo_list":
        await admin_promo_list_handler(query)
    
    elif data == "admin_promos_back":
        await admin_promos_panel(query)
    
    elif data == "admin_stats":
        await admin_stats_panel(query, context)
    
    elif data == "admin_settings":
        await admin_settings_panel(query)
    
    elif data.startswith("admin_settings_"):
        await admin_settings_handler(query, context)
    
    elif data == "admin_ads":
        fake_update = Update(update.update_id, message=query.message)
        await remove_ad_command(fake_update, context)
    
    elif data == "admin_exchange":
        fake_update = Update(update.update_id, message=query.message)
        await kurs_command(fake_update, context)
    
    elif data == "admin_credits":
        await query.answer("Кредитные заявки уже отображаются в меню кредитов")
    
    await query.answer()

async def admin_panel_from_callback(query, context):
    keyboard = [
        [InlineKeyboardButton("👥 Пользователи", callback_data="admin_users")],
        [InlineKeyboardButton("🎫 Управление промокодами", callback_data="admin_promos")],
        [InlineKeyboardButton("📢 Управление рекламой", callback_data="admin_ads")],
        [InlineKeyboardButton("💱 Управление курсом", callback_data="admin_exchange")],
        [InlineKeyboardButton("💰 Кредитные заявки", callback_data="admin_credits")],
        [InlineKeyboardButton("📊 Статистика", callback_data="admin_stats")],
        [InlineKeyboardButton("⚙️ Настройки", callback_data="admin_settings")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "🛠 <b>Панель администратора</b>\n\n"
        "Выберите раздел для управления:",
        parse_mode=ParseMode.HTML,
        reply_markup=reply_markup
    )

async def give_money_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False) and user.id not in ADMIN_IDS:
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if len(context.args) < 2:
        await update.message.reply_text("Использование: /givemod [@username] [сумма]")
        return
    
    username = context.args[0].replace('@', '')
    try:
        amount = parse_bet(context.args[1])
    except:
        await update.message.reply_text("Неверный формат суммы")
        return
    
    receiver_id = None
    for uid, data in db.data.items():
        if data.get('username', '').lower() == username.lower():
            receiver_id = uid
            break
    
    if not receiver_id:
        if username.isdigit():
            receiver_id = username
        else:
            await update.message.reply_text("❌ Пользователь не найден")
            return
    
    receiver_data = db.get_user(int(receiver_id))
    receiver_data['balance'] += amount
    
    db.update_user(int(receiver_id), receiver_data)
    
    await update.message.reply_text(
        f"✅ Выдано {format_number(amount)} Vscoin пользователю {receiver_data.get('username', 'Unknown')}\n"
        f"💰 Новый баланс: {format_number(receiver_data['balance'])} Vscoin"
    )

async def take_money_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False) and user.id not in ADMIN_IDS:
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if len(context.args) < 2:
        await update.message.reply_text("Использование: /nogive [@username] [сумма]")
        return
    
    username = context.args[0].replace('@', '')
    try:
        amount = parse_bet(context.args[1])
    except:
        await update.message.reply_text("Неверный формат суммы")
        return
    
    receiver_id = None
    for uid, data in db.data.items():
        if data.get('username', '').lower() == username.lower():
            receiver_id = uid
            break
    
    if not receiver_id:
        if username.isdigit():
            receiver_id = username
        else:
            await update.message.reply_text("❌ Пользователь не найден")
            return
    
    receiver_data = db.get_user(int(receiver_id))
    
    if receiver_data['balance'] < amount:
        amount = receiver_data['balance']
    
    receiver_data['balance'] -= amount
    db.update_user(int(receiver_id), receiver_data)
    
    await update.message.reply_text(
        f"✅ Изъято {format_number(amount)} Vscoin у пользователя {receiver_data.get('username', 'Unknown')}\n"
        f"💰 Новый баланс: {format_number(receiver_data['balance'])} Vscoin"
    )

async def broadcast_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_data = db.get_user(user.id)
    
    if not user_data.get('is_admin', False) and user.id not in ADMIN_IDS:
        await update.message.reply_text("❌ У вас нет прав для выполнения этой команды")
        return
    
    if len(context.args) < 1:
        await update.message.reply_text("Использование: /t [сообщение]")
        return
    
    message = ' '.join(context.args)
    total_users = len(db.data)
    success = 0
    failed = 0
    
    for user_id in db.data:
        try:
            await context.bot.send_message(chat_id=user_id, text=message)
            success += 1
        except Exception as e:
            failed += 1
    
    await update.message.reply_text(
        f"✅ Рассылка завершена!\n"
        f"Всего пользователей: {total_users}\n"
        f"Успешно: {success}\n"
        f"Не удалось: {failed}"
    )
    
async def handle_text_helper(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик текстовых команд для помощников"""
    user = update.effective_user
    user_data = db.get_user(user.id)
    text = update.message.text.strip()
    
    # Проверяем права пользователя
    helper_rank = user_data.get('helper_rank', 0)
    is_admin = user_data.get('is_admin', False)
    
    if not (helper_rank >= 3 or is_admin):
        return  # Недостаточно прав
    
    # Проверяем, ожидаем ли мы создание промокода
    if 'awaiting_promo_data' in context.user_data and context.user_data['awaiting_promo_data']:
        try:
            # Разбираем ввод пользователя: код сумма кол-во_активаций
            parts = text.split()
            
            if len(parts) != 3:
                await update.message.reply_text(
                    "❌ Неверный формат!\n\n"
                    "Использование: <code>КОД СУММА КОЛ-ВО_АКТИВАЦИЙ</code>\n\n"
                    "Пример: <code>PROMO2024 5000 5</code>\n"
                    "Создаст промокод PROMO2024 с наградой 5000 Vscoin на 5 активаций",
                    parse_mode=ParseMode.HTML
                )
                return
            
            promo_code = parts[0].upper()
            amount = int(parts[1])
            uses = int(parts[2])
            
            # Проверяем валидность данных
            if amount <= 0:
                await update.message.reply_text("❌ Сумма должна быть положительной!")
                return
            
            if uses <= 0:
                await update.message.reply_text("❌ Количество активаций должно быть положительным!")
                return
            
            # Проверяем, не существует ли уже такой промокод
            all_promocodes = db.get_all_promocodes()
            if promo_code in all_promocodes:
                await update.message.reply_text(
                    f"❌ Промокод <b>{promo_code}</b> уже существует!",
                    parse_mode=ParseMode.HTML
                )
                return
            
            # Создаем промокод
            db.add_promocode(promo_code, amount, uses)
            
            # Логируем действие
            db.log_helper_action(
                user.id,
                "Создание промокода",
                f"Создал промокод {promo_code}: {amount} Vscoin, {uses} активаций"
            )
            
            # Отправляем подтверждение
            await update.message.reply_text(
                f"✅ <b>Промокод успешно создан!</b>\n\n"
                f"🎫 <b>Название:</b> <code>{promo_code}</code>\n"
                f"💰 <b>Вознаграждение:</b> {format_number(amount)} Vscoin\n"
                f"🔢 <b>Активаций:</b> {uses}\n\n"
                f"📝 <i>Что бы активировать его напишите <code>промо {promo_code}</code></i>",
                parse_mode=ParseMode.HTML
            )
            
            # Сбрасываем состояние
            del context.user_data['awaiting_promo_data']
            
        except ValueError:
            await update.message.reply_text(
                "❌ Неверный формат чисел!\n"
                "Убедитесь что сумма и количество активаций - целые числа.\n\n"
                "Пример: <code>PROMO2024 5000 5</code>",
                parse_mode=ParseMode.HTML
            )
        except Exception as e:
            print(f"Ошибка создания промокода: {e}")
            await update.message.reply_text("❌ Ошибка при создании промокода. Попробуйте снова.")
    
    # Обработка других текстовых команд помощников
    elif text.lower().startswith('бан '):
        # Обработка команд бана через текст
        await handle_ban_text_command(update, context, user_data)
    
    elif text.lower().startswith('разбан '):
        # Обработка команд разбана через текст
        await handle_unban_text_command(update, context, user_data)
    
    elif text.lower().startswith('кредит '):
        # Обработка кредитных заявок через текст
        await handle_credit_text_command(update, context, user_data)
    
    # Добавьте здесь другие текстовые команды для помощников


async def create_promocode_prompt(query, context: ContextTypes.DEFAULT_TYPE):
    """Запрос данных для создания промокода"""
    await query.edit_message_text(
        "🎫 <b>Создание промокода</b>\n\n"
        "📝 <b>Формат:</b> <code>КОД СУММА КОЛ-ВО_АКТИВАЦИЙ</code>\n\n"
        "📋 <b>Пример:</b>\n"
        "<code>PROMO2024 5000 5</code>\n\n"
        "Создаст промокод PROMO2024 с наградой 5000 Vscoin на 5 активаций.\n\n"
        "✏️ <i>Отправьте данные в одном сообщении:</i>",
        parse_mode=ParseMode.HTML
    )
    
    # Устанавливаем состояние ожидания данных промокода
    context.user_data['awaiting_promo_data'] = True
    
# ==================== СОВМЕЩЕННАЯ ФУНКЦИЯ ОБРАБОТКИ ТЕКСТА ====================

async def cancel_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Команда /cancel для отмены текущего действия"""
    user = update.effective_user
    
    # Очищаем все состояния пользователя
    keys_to_delete = []
    
    # Ищем все ключи связанные с этим пользователем
    for key in list(context.user_data.keys()):
        if str(user.id) in str(key):
            keys_to_delete.append(key)
    
    # Удаляем найденные ключи
    for key in keys_to_delete:
        del context.user_data[key]
    
    # Также очищаем общие состояния
    general_states = [
        'awaiting_business_withdraw',
        'awaiting_deposit_amount',
        'awaiting_withdraw_amount',
        'awaiting_credit_amount',
        'awaiting_credit_term',
        'awaiting_ban_request',
        'awaiting_unban',
        'awaiting_promo',
        'awaiting_helper_bonus',
        'admin_action',
        'withdraw_user_id',
        'ban_user_id',
        'unban_user_id',
        'promo_user_id',
        'bonus_helper_id',
        'deposit_user_id'
    ]
    
    for state in general_states:
        if state in context.user_data:
            del context.user_data[state]
    
    await update.message.reply_text(
        "✅ Все активные действия отменены",
        parse_mode=ParseMode.HTML
    )

# И в основном коде добавьте обработчик:


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик текстовых сообщений (команды без слеша и русские сленги)"""
    user = update.effective_user
    message = update.message
    text = message.text.strip().lower() if message.text else ""
    
    # Если текст пустой
    if not text:
        return
    
    # Получаем данные пользователя
    user_data = db.get_user(user.id)
    
    
    
    # ============ 1. СНАЧАЛА ПРОВЕРЯЕМ СОСТОЯНИЯ ВВОДА (самое важное!) ============
    
    # 1.1. Пароль для активации чека
    if f'check_activate_password_{user.id}' in context.user_data:
        check_data = context.user_data[f'check_activate_password_{user.id}']
        check_id = check_data['check_id']
        
        check_info = db.get_check(check_id)
        if not check_info:
            del context.user_data[f'check_activate_password_{user.id}']
            await update.message.reply_text("❌ Чек не найден")
            return
        
        # Проверяем пароль
        if check_info['password'] != text:
            await update.message.reply_text(
                "❌ Неверный пароль!\n"
                "Попробуйте снова или введите /cancel для отмены",
                parse_mode=ParseMode.HTML
            )
            return
        
        # Активируем чек
        success, message_text = db.activate_check(check_id, user.id, text)
        
        if success:
            del context.user_data[f'check_activate_password_{user.id}']
            user_data = db.get_user(user.id)
            user_link = f'<a href="tg://user?id={user.id}">{user.full_name}</a>'
            
            await update.message.reply_text(
                f"✅ {user_link}, вы успешно активировали чек!\n"
                f"💰 Получено: {format_number(check_info['amount'])} VsCoin\n"
                f"💳 Ваш баланс: {format_number(user_data['balance'])} VsCoin",
                parse_mode=ParseMode.HTML
            )
        else:
            await update.message.reply_text(f"❌ {message_text}")
        return
    
    # 1.2. Ввод данных для создания/редактирования чеков
    if f'check_input_{user.id}' in context.user_data:
        input_type = context.user_data[f'check_input_{user.id}']
        
        if input_type == 'amount':
            # Обработка ввода суммы чека
            try:
                user_data = db.get_user(user.id)
                amount = parse_bet(text, user_data['balance'])
                
                if amount < MIN_CHECK_AMOUNT:
                    await update.message.reply_text(
                        f"❌ Минимальная сумма: {MIN_CHECK_AMOUNT} Vscoin"
                    )
                    return
                
                if amount > MAX_CHECK_AMOUNT:
                    await update.message.reply_text(
                        f"❌ Максимальная сумма: {format_number(MAX_CHECK_AMOUNT)} Vscoin"
                    )
                    return
                
                if amount > user_data['balance']:
                    await update.message.reply_text(
                        f"❌ Недостаточно средств! Доступно: {format_number(user_data['balance'])} Vscoin"
                    )
                    return
                
                # Рассчитываем максимальное количество активаций
                max_activations_by_limit = 1000000 // amount
                max_activations_by_balance = user_data['balance'] // amount
                max_activations = min(max_activations_by_limit, max_activations_by_balance)
                
                if max_activations < 1:
                    await update.message.reply_text("❌ Недостаточно средств для создания чека")
                    return
                
                # Сохраняем сумму в context
                if f'check_create_{user.id}' not in context.user_data:
                    context.user_data[f'check_create_{user.id}'] = {}
                
                context.user_data[f'check_create_{user.id}']['amount'] = amount
                
                # Кнопки для выбора количества активаций
                keyboard = []
                keyboard.append([
                    InlineKeyboardButton(
                        f"1 активация = {format_number(amount)} Vscoin", 
                        callback_data="check_act_min"
                    )
                ])
                keyboard.append([
                    InlineKeyboardButton(
                        f"{max_activations} активаций = {format_number(amount * max_activations)} Vscoin", 
                        callback_data="check_act_max"
                    )
                ])
                keyboard.append([InlineKeyboardButton("🔙 Назад", callback_data="check_create")])
                
                reply_markup = InlineKeyboardMarkup(keyboard)
                
                # Удаляем флаг ввода
                del context.user_data[f'check_input_{user.id}']
                
                await update.message.reply_text(
                    f"✅ <b>СУММА ПРИНЯТА!</b>\n"
                    f"💰 <b>Сумма за активацию:</b> {format_number(amount)} Vscoin\n"
                    f"💳 <b>Ваш баланс:</b> {format_number(user_data['balance'])} Vscoin\n"
                    f"🧮 <b>Макс. активаций:</b> {max_activations}\n\n"
                    f"Выберите количество активаций:",
                    parse_mode=ParseMode.HTML,
                    reply_markup=reply_markup
                )
                return
                
            except Exception as e:
                print(f"Ошибка при обработке суммы чека: {e}")
                await update.message.reply_text("❌ Неверный формат суммы!")
                return
        
        elif input_type == 'password':
            # Обработка ввода пароля для чека
            check_id = context.user_data.get(f'check_setpass_{user.id}')
            if check_id:
                # Удаляем пароль если ввели 0
                if text == '0':
                    password = None
                else:
                    # Проверяем пароль
                    if len(text) < 4 or len(text) > 20:
                        await update.message.reply_text("❌ Пароль должен содержать от 4 до 20 символов")
                        return
                    password = text
                
                # Обновляем пароль в базе данных
                success = db.set_check_password(check_id, password)
                
                # Удаляем флаги
                del context.user_data[f'check_input_{user.id}']
                del context.user_data[f'check_setpass_{user.id}']
                
                if success:
                    if password:
                        await update.message.reply_text(f"✅ Пароль успешно установлен!")
                    else:
                        await update.message.reply_text("✅ Пароль успешно удален!")
                else:
                    await update.message.reply_text("❌ Ошибка при установке пароля")
                return
        
        elif input_type == 'description':
            # Обработка ввода описания для чека
            check_id = context.user_data.get(f'check_setdesc_{user.id}')
            if check_id:
                # Удаляем описание если ввели 0
                if text == '0':
                    description = None
                else:
                    # Проверяем описание
                    if len(text) > 100:
                        await update.message.reply_text("❌ Описание не может превышать 100 символов")
                        return
                    description = text
                
                # Обновляем описание в базе данных
                success = db.set_check_description(check_id, description)
                
                # Удаляем флаги
                del context.user_data[f'check_input_{user.id}']
                del context.user_data[f'check_setdesc_{user.id}']
                
                if success:
                    if description:
                        await update.message.reply_text(f"✅ Описание успешно добавлено!")
                    else:
                        await update.message.reply_text("✅ Описание успешно удалено!")
                else:
                    await update.message.reply_text("❌ Ошибка при добавлении описания")
                return
    
    # 1.3. Состояния для админов/хелперов
    if context.user_data.get('awaiting_ban_request') and context.user_data.get('ban_user_id') == user.id:
        await process_ban_request(update, context, text)
        return
    
    if context.user_data.get('awaiting_unban') and context.user_data.get('unban_user_id') == user.id:
        await process_unban_request(update, context, text)
        return
    
    if context.user_data.get('awaiting_promo') and context.user_data.get('promo_user_id') == user.id:
        await process_promo_request(update, context, text)
        return
    
    if context.user_data.get('awaiting_helper_bonus') and context.user_data.get('bonus_helper_id') == user.id:
        await process_helper_bonus(update, context, text)
        return
    
    # 1.4. Состояния для бизнеса
    if context.user_data.get('awaiting_business_withdraw') and context.user_data.get('withdraw_user_id') == user.id:
        await handle_business_withdraw(update, context)
        return
    
    # 1.5. Состояния для банка
    if context.user_data.get('awaiting_deposit_amount'):
        await handle_deposit_text(update, context)
        return
    
    if context.user_data.get('awaiting_withdraw_amount'):
        await handle_deposit_text(update, context)
        return
    
    if context.user_data.get('awaiting_credit_amount'):
        await handle_bank_text(update, context)
        return
    
    if context.user_data.get('awaiting_credit_term'):
        await handle_bank_text(update, context)
        return
    
    # 1.6. Состояния для админских действий
    if 'admin_action' in context.user_data:
        if context.user_data['admin_action']['type'] in ['give', 'take', 'ban']:
            await handle_admin_user_actions(update, context)
            return
        elif context.user_data['admin_action']['type'] in ['create_promo', 'delete_promo']:
            await handle_admin_promo_actions(update, context)
            return
    
    # ============ 2. ПОТОМ ПРОВЕРЯЕМ РУССКИЕ КОМАНДЫ ============
    
    # Основные команды пользователя
    if text in ['б', 'баланс', 'balance']:
        await balance(update, context)
        return
    elif text == 'игры':
        await game_command(update, context)
        return
    elif text == 'профиль':
        await profile(update, context)
        return
    elif text == 'бонус':
        await bonus(update, context)
        return
    elif text == 'топ':
        await top(update, context)
        return
    elif text == 'помощь':
        await help_command(update, context)
        return
    elif text == 'старт':
        await start(update, context)
        return
    
    # Финансовые команды
    elif text.startswith('перевести'):
        context.args = text.split()[1:]
        await give_money(update, context)
        return
    elif text.startswith('дать'):
        context.args = text.split()[1:]
        await give_money(update, context)
        return
    elif text.startswith('промо'):
        context.args = text.split()[1:]
        await promo_command(update, context)
        return
    elif text == 'заработать':
        await earn_command(update, context)
        return
    elif text == 'обменник':
        await exchange_command(update, context)
        return
    
    # Бизнес-команды
    elif text == 'бизнес':
        await business_command(update, context)
        return
    elif text.startswith('купитьбизнес'):
        context.args = text.split()[1:]
        await buy_business_command(update, context)
        return
    elif text == 'управлениебизнесом':
        await business_management_command(update, context)
        return
    
    # Банковские команды
    elif text == 'банк':
        await bank_command(update, context)
        return
    elif text == 'кредит':
        await credit_command(update, context)
        return
    
    # Игровые команды
    elif text.startswith('мины'):
        context.args = text.split()[1:]
        if len(context.args) == 1:
            context.args.append("1")
        await mines_game(update, context)
        return
    elif text.startswith('золото'):
        context.args = text.split()[1:]
        await gold_game(update, context)
        return
    elif text.startswith('футбол'):
        context.args = text.split()[1:]
        await football_game(update, context)
        return
    elif text.startswith('баскетбол'):
        context.args = text.split()[1:]
        await basketball_game(update, context)
        return
    elif text.startswith('рулетка'):
        context.args = text.split()[1:]
        await roulette_game(update, context)
        return
    elif text.startswith('21'):
        context.args = text.split()[1:]
        await twentyone_game(update, context)
        return
    elif text.startswith('кости'):
        context.args = text.split()[1:]
        await cubes_game(update, context)
        return
    elif text == 'на все':
        await allin_game(update, context)
        return
    elif text.startswith('башня'):
        context.args = text.split()[1:]
        if len(context.args) == 1:
            context.args.append("1")
        await tower_game(update, context)
        return
    elif text.startswith('хило'):
        context.args = text.split()[1:]
        await hilo_game(update, context)
        return
    elif text.startswith('сундук'):
        context.args = text.split()[1:]
        await chest_game(update, context)
        return
    elif text.startswith('дуэль'):
        context.args = text.split()[1:]
        await duel_game(update, context)
        return
    elif text.startswith('дартс'):
        context.args = text.split()[1:]
        await darts_game(update, context)
        return
    elif text.startswith('алмазы'):
        context.args = text.split()[1:]
        await pyramid_game(update, context)
        return
    elif text.startswith('краш'):
        context.args = text.split()[1:]
        await crash_game(update, context)
        return
    # Административные команды (только для админов/хелперов)
    elif text.startswith('админ'):
        context.args = text.split()[1:]
        await admin_panel(update, context)
        return
    elif text.startswith('выдать'):
        context.args = text.split()[1:]
        await give_money_admin(update, context)
        return
    elif text.startswith('забрать'):
        context.args = text.split()[1:]
        await take_money_admin(update, context)
        return
    elif text.startswith('бан'):
        context.args = text.split()[1:]
        await ban_user(update, context)
        return
    elif text.startswith('разбан'):
        context.args = text.split()[1:]
        await unban_user(update, context)
        return
    elif text.startswith('промокод'):
        context.args = text.split()[1:]
        await create_promocode(update, context)
        return
    elif text.startswith('реклама'):
        context.args = text.split()[1:]
        await advertisement_command(update, context)
        return
    elif text == 'убратьрекламу':
        await remove_ad_command(update, context)
        return
    elif text.startswith('курс'):
        context.args = text.split()[1:]
        await kurs_command(update, context)
        return
    elif text in ['статистика', 'stats']:
        await stats_command(update, context)
        return
    
    # Хелпер команды
    elif text.startswith('хелпер'):
        await helper_command(update, context)
        return
    
    # ============ 3. ЕСЛИ НИЧЕГО НЕ СРАБОТАЛО ============
   
    
def main():
    """Запуск бота"""
    application = Application.builder().token(BOT_TOKEN).build()
    
    # ============ КОМАНДЫ ============
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("game", game_command))
    application.add_handler(CommandHandler("profile", profile))
    application.add_handler(CommandHandler("balance", balance))
    application.add_handler(CommandHandler("bonus", bonus))
    application.add_handler(CommandHandler("top", top))
    application.add_handler(CommandHandler("transfer", give_money))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(CommandHandler("promo", promo_command))
    application.add_handler(CommandHandler("earn", earn_command))
    application.add_handler(CommandHandler("exchange", exchange_command))
    application.add_handler(CommandHandler("rate", kurs_command))
    application.add_handler(CommandHandler("advertisement", advertisement_command))
    application.add_handler(CommandHandler("removead", remove_ad_command))
    application.add_handler(CommandHandler("business", business_command))
    application.add_handler(CommandHandler("buybusiness", buy_business_command))
    application.add_handler(CommandHandler("managebusiness", business_management_command))
    application.add_handler(CommandHandler("bank", bank_command))
    application.add_handler(CommandHandler("credit", credit_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    
    # ============ ИГРЫ ============
    application.add_handler(CommandHandler("mines", mines_game))
    application.add_handler(CommandHandler("football", football_game))
    application.add_handler(CommandHandler("basketball", basketball_game))
    application.add_handler(CommandHandler("darts", darts_game))
    application.add_handler(CommandHandler("roulette", roulette_game))
    application.add_handler(CommandHandler("twentyone", twentyone_game))
    application.add_handler(CommandHandler("cubes", cubes_game))
    application.add_handler(CommandHandler("hilo", hilo_game))
    application.add_handler(CommandHandler("allin", allin_game))
    application.add_handler(CommandHandler("gold", gold_game))
    application.add_handler(CommandHandler("tower", tower_game))
    application.add_handler(CommandHandler("chest", chest_game))
    application.add_handler(CommandHandler("crash", crash_game))
    
    # ============ АДМИН КОМАНДЫ ============
    application.add_handler(CommandHandler("admin", admin_panel))
  
    application.add_handler(CommandHandler("givemoney", give_money_admin))
    application.add_handler(CommandHandler("takemoney", take_money_admin))
 
    # ============ ХЕЛПЕР КОМАНДЫ ============
    # Добавьте эти обработчики
 # В функции main() добавьте:

  

    application.add_handler(CallbackQueryHandler(daily_bonus_callback, pattern="^daily_bonus$"))
    application.add_handler(CallbackQueryHandler(daily_cell_callback, pattern="^daily_cell_"))
    
    application.add_handler(CommandHandler("helper", helper_command))

    application.add_handler(CommandHandler("helper1", helper1_command))
    application.add_handler(CommandHandler("helper2", helper2_command))
    application.add_handler(CommandHandler("helper3", helper3_command))
    application.add_handler(CommandHandler("removehelper", remove_helper_command))
    
    # ============ CALLBACK ОБРАБОТЧИКИ ============
 # 1. Сначала обработчик активации чека (самый специфичный)
    application.add_handler(CallbackQueryHandler(handle_check_activation, pattern="^check_activate_"))

# 2. Затем обработчик подтверждения удаления (также специфичный)
    application.add_handler(CallbackQueryHandler(check_callback, pattern="^check_delete_confirm_"))

# 3. Основной обработчик для всех остальных callback чеков
    application.add_handler(CallbackQueryHandler(check_callback, pattern="^check_"))

# 4. Команда /check
    application.add_handler(CommandHandler("check", check_command))

    application.add_handler(CallbackQueryHandler(helper_callback, pattern="^helper_"))
    
    application.add_handler(CallbackQueryHandler(help_callback, pattern="^help_"))
    application.add_handler(CallbackQueryHandler(balance_callback, pattern="^balance_"))
    application.add_handler(CallbackQueryHandler(refresh_top_callback, pattern="^refresh_top$"))
    application.add_handler(CallbackQueryHandler(earn_callback, pattern="^earn_"))
    application.add_handler(CallbackQueryHandler(check_sub_callback, pattern="^check_sub_"))
    application.add_handler(CallbackQueryHandler(exchange_callback, pattern="^exchange_"))
    application.add_handler(CallbackQueryHandler(remove_ad_callback, pattern="^removead_"))
    application.add_handler(CallbackQueryHandler(biz_management_callback, pattern="^biz_"))
    application.add_handler(CallbackQueryHandler(bank_callback, pattern="^bank_"))
    application.add_handler(CallbackQueryHandler(deposit_callback, pattern="^deposit_"))
    application.add_handler(CallbackQueryHandler(credit_callback, pattern="^credit_"))
    application.add_handler(CommandHandler("cancel", cancel_command))
    # ============ ИГРОВЫЕ CALLBACK ============
    application.add_handler(CallbackQueryHandler(mines_callback, pattern="^mines_"))
    application.add_handler(CallbackQueryHandler(mines_finished_callback, pattern="^mines_finished$"))
    application.add_handler(CallbackQueryHandler(football_callback, pattern="^fb_"))
    application.add_handler(CallbackQueryHandler(basketball_callback, pattern="^bb_"))
    application.add_handler(CallbackQueryHandler(darts_callback, pattern="^dart_"))
    application.add_handler(CallbackQueryHandler(tower_callback, pattern="^tower_"))
    application.add_handler(CallbackQueryHandler(tower_finished_callback, pattern="^tower_finished$"))
    application.add_handler(CallbackQueryHandler(gold_callback, pattern="^gold_"))
    application.add_handler(CallbackQueryHandler(chest_callback, pattern="^chest_"))
    application.add_handler(CallbackQueryHandler(cubes_callback, pattern="^cubes_"))
    application.add_handler(CallbackQueryHandler(hilo_callback, pattern="^hilo_"))
    application.add_handler(CallbackQueryHandler(twentyone_callback, pattern="^twentyone_"))
    application.add_handler(CallbackQueryHandler(game_callback, pattern="^game_"))
    application.add_handler(CommandHandler("almaz", pyramid_game))
    application.add_handler(CallbackQueryHandler(pyramid_callback, pattern="^pyramid_"))
    application.add_handler(CallbackQueryHandler(give_callback, pattern="^transfer_"))
    # ============ АДМИН CALLBACK ============
    application.add_handler(CallbackQueryHandler(admin_callback_handler, pattern="^admin_"))
    
    # ============ ХЕЛПЕР CALLBACK ============
 
    # ============ ОБРАБОТЧИКИ ТЕКСТА ============
    # Главный обработчик текста (должен быть ПЕРВЫМ!)
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    
    # Дополнительные обработчики текста
   
    print("✅ Все обработчики добавлены")
    print("🤖 Запуск бота...")
    print(f"🔐 Токен: {BOT_TOKEN[:10]}...")
    application.run_polling(allowed_updates=Update.ALL_TYPES, drop_pending_updates=True)

# ============ START PROGRAM ============
if __name__ == '__main__':
    main()