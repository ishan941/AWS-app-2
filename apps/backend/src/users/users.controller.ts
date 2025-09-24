import { Controller, Get, Param } from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from '@aws-app/shared';

@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Get()
    findAll(): User[] {
        return this.usersService.findAll();
    }

    @Get(':id')
    findOne(@Param('id') id: string): User | null {
        return this.usersService.findOne(id);
    }
}